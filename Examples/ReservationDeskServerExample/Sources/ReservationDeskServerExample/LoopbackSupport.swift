import Foundation
import NIOCore
import SwiftSOAPCore
import SwiftSOAPServerAsync
import SwiftSOAPServerNIO

final class ReservationLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var nextReservationNumber: Int
    private var reservations: [String: ReservationRecord]

    init(seedReservations: [ReservationRecord], nextReservationNumber: Int = 1200) {
        self.nextReservationNumber = nextReservationNumber
        self.reservations = Dictionary(uniqueKeysWithValues: seedReservations.map { ($0.id, $0) })
    }

    static func demo() -> ReservationLedger {
        ReservationLedger(
            seedReservations: [
                ReservationRecord(
                    id: "RES-LOCKED-001",
                    status: "checked-in",
                    quotedAmount: 449.00,
                    canCancel: false,
                    events: [
                        ReservationEvent(timestamp: "2026-03-01T09:00:00Z", category: "created", summary: "Imported from PMS"),
                        ReservationEvent(timestamp: "2026-03-14T14:10:00Z", category: "check-in", summary: "Guest already checked in")
                    ]
                )
            ]
        )
    }

    func createReservation(
        guestEmail: String,
        roomCode: String,
        arrivalDate: String,
        nights: Int
    ) -> Result<ReservationRecord, ReservationProblem> {
        lock.lock()
        defer { lock.unlock() }

        if roomCode.uppercased() == "BLOCKED" {
            return .failure(
                ReservationProblem(
                    code: "room-unavailable",
                    message: "The requested room category is not available for self-service booking.",
                    retryable: true
                )
            )
        }

        let reservationId = "RES-\(nextReservationNumber)"
        nextReservationNumber += 1
        let quotedAmount = Double(nights) * 189.00
        let record = ReservationRecord(
            id: reservationId,
            status: "confirmed",
            quotedAmount: quotedAmount,
            canCancel: true,
            events: [
                ReservationEvent(timestamp: isoTimestamp(), category: "created", summary: "Booked for \(guestEmail)"),
                ReservationEvent(timestamp: isoTimestamp(), category: "inventory", summary: "Assigned room category \(roomCode)"),
                ReservationEvent(timestamp: isoTimestamp(), category: "arrival", summary: "Arrival planned on \(arrivalDate) for \(nights) nights")
            ]
        )
        reservations[reservationId] = record
        return .success(record)
    }

    func appendReservationNote(reservationId: String, author: String, note: String) -> ReservationRecord? {
        lock.lock()
        defer { lock.unlock() }

        guard var record = reservations[reservationId] else {
            return nil
        }

        record.events.append(
            ReservationEvent(
                timestamp: isoTimestamp(),
                category: "note",
                summary: "\(author): \(note)"
            )
        )
        reservations[reservationId] = record
        return record
    }

    func reservation(for reservationId: String) -> ReservationRecord? {
        lock.lock()
        defer { lock.unlock() }
        return reservations[reservationId]
    }

    func cancelReservation(reservationId: String, reason: String) -> Result<ReservationCancellation, ReservationProblem> {
        lock.lock()
        defer { lock.unlock() }

        guard var record = reservations[reservationId] else {
            return .failure(
                ReservationProblem(
                    code: "reservation-not-found",
                    message: "No reservation exists for id \(reservationId).",
                    retryable: false
                )
            )
        }

        guard record.canCancel else {
            return .failure(
                ReservationProblem(
                    code: "reservation-locked",
                    message: "Reservation \(reservationId) can no longer be cancelled online.",
                    retryable: false
                )
            )
        }

        record.status = "cancelled"
        record.canCancel = false
        record.events.append(
            ReservationEvent(
                timestamp: isoTimestamp(),
                category: "cancelled",
                summary: "Cancelled by guest: \(reason)"
            )
        )
        reservations[reservationId] = record

        return .success(
            ReservationCancellation(
                reservationId: reservationId,
                cancelledAt: isoTimestamp(),
                refundAmount: record.quotedAmount
            )
        )
    }

    private func isoTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}

struct ReservationRecord: Sendable {
    let id: String
    var status: String
    let quotedAmount: Double
    var canCancel: Bool
    var events: [ReservationEvent]
}

struct ReservationEvent: Sendable {
    let timestamp: String
    let category: String
    let summary: String
}

struct ReservationProblem: Error, Sendable {
    let code: String
    let message: String
    let retryable: Bool
}

struct ReservationCancellation: Sendable {
    let reservationId: String
    let cancelledAt: String
    let refundAmount: Double
}

actor AsyncLoopbackServer: SOAPServerAsync {
    private typealias ErasedHandler = @Sendable (Any) async throws(any Error) -> Any

    private var handlers: [String: ErasedHandler] = [:]

    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPAsyncOperationHandler<Operation>
    ) async throws(any Error) {
        handlers[operation.operationIdentifier.rawValue] = { request in
            guard let typedRequest = request as? Operation.RequestPayload else {
                throw SOAPCoreError.invalidPayload(message: "Invalid async request payload for operation \(operation.operationIdentifier.rawValue).")
            }
            return try await handler(typedRequest)
        }
    }

    func start() async throws(any Error) {}

    func stop() async throws(any Error) {}

    func dispatch<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload
    ) async throws(any Error) -> SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload> {
        guard let handler = handlers[operation.operationIdentifier.rawValue] else {
            throw SOAPCoreError.invalidPayload(message: "Missing async operation handler for \(operation.operationIdentifier.rawValue).")
        }

        let response = try await handler(request)
        guard let typedResponse = response as? SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload> else {
            throw SOAPCoreError.invalidPayload(message: "Invalid async response payload for \(operation.operationIdentifier.rawValue).")
        }
        return typedResponse
    }
}

final class NIOLoopbackServer: SOAPServerNIO, @unchecked Sendable {
    private typealias ErasedHandler = (Any, EventLoop) -> EventLoopFuture<Any>

    private var handlers: [String: ErasedHandler] = [:]

    func register<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        handler: @escaping SOAPNIOOperationHandler<Operation>
    ) {
        handlers[operation.operationIdentifier.rawValue] = { request, eventLoop in
            guard let typedRequest = request as? Operation.RequestPayload else {
                return eventLoop.makeFailedFuture(
                    SOAPCoreError.invalidPayload(message: "Invalid NIO request payload for operation \(operation.operationIdentifier.rawValue).")
                )
            }

            return handler(typedRequest, eventLoop).flatMapThrowing { response in
                response as Any
            }
        }
    }

    func start(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        eventLoop.makeSucceededFuture(())
    }

    func stop(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        eventLoop.makeSucceededFuture(())
    }

    func dispatch<Operation: SOAPOperationContract>(
        _ operation: Operation.Type,
        request: Operation.RequestPayload,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload>> {
        guard let handler = handlers[operation.operationIdentifier.rawValue] else {
            return eventLoop.makeFailedFuture(
                SOAPCoreError.invalidPayload(message: "Missing NIO operation handler for \(operation.operationIdentifier.rawValue).")
            )
        }

        return handler(request, eventLoop).flatMapThrowing { response in
            guard let typedResponse = response as? SOAPOperationResponse<Operation.ResponsePayload, Operation.FaultDetailPayload> else {
                throw SOAPCoreError.invalidPayload(message: "Invalid NIO response payload for \(operation.operationIdentifier.rawValue).")
            }
            return typedResponse
        }
    }
}
