import Foundation
import NIOCore
import NIOEmbedded
import SwiftSOAPCore

@main
struct ReservationDeskServerExample {
    static func main() async throws {
        print("=== Async server example ===")
        try await runAsyncDemo()
        print("")
        print("=== NIO server example ===")
        try runNIODemo()
    }

    private static func runAsyncDemo() async throws {
        let server = AsyncLoopbackServer()
        let registrar = ReservationDeskAgentPortAsyncServerRegistrar(server: server)
        let implementation = AsyncReservationService(ledger: ReservationLedger.demo())

        try await registrar.register(implementation: implementation)
        try await server.start()
        defer { Task { try? await server.stop() } }

        let createResponse = try await server.dispatch(
            ReservationDeskAgentPortCreateReservationOperation.self,
            request: CreateReservationRequestPayload(
                guestEmail: "ada@example.com",
                roomCode: "DLX",
                arrivalDate: "2026-04-02",
                nights: 3
            )
        )

        let reservationId: String
        switch createResponse {
        case .success(let payload):
            reservationId = payload.reservationId
            print("createReservation -> success id=\(payload.reservationId) status=\(payload.status) quote=\(payload.quotedAmount)")
        case .fault(let fault):
            print("createReservation -> unexpected fault \(fault.faultString)")
            return
        }

        let noteResponse = try await server.dispatch(
            ReservationDeskAgentPortAppendReservationNoteOperation.self,
            request: AppendReservationNoteRequestPayload(
                reservationId: reservationId,
                author: "front-desk",
                note: "Guest requested a quiet room if available."
            )
        )
        switch noteResponse {
        case .success:
            print("appendReservationNote -> success (empty business response)")
        case .fault(let fault):
            print("appendReservationNote -> unexpected fault \(fault.faultString)")
        }

        let timelineResponse = try await server.dispatch(
            ReservationDeskAgentPortGetReservationTimelineOperation.self,
            request: GetReservationTimelineRequestPayload(reservationId: reservationId)
        )
        switch timelineResponse {
        case .success(let payload):
            let eventCount = payload.events?.count ?? 0
            print("getReservationTimeline -> status=\(payload.status) events=\(eventCount)")
        case .fault(let fault):
            print("getReservationTimeline -> unexpected fault \(fault.faultString)")
        }

        let cancelLockedResponse = try await server.dispatch(
            ReservationDeskAgentPortCancelReservationOperation.self,
            request: CancelReservationRequestPayload(
                reservationId: "RES-LOCKED-001",
                reason: "Guest tried to cancel after arrival."
            )
        )
        switch cancelLockedResponse {
        case .success(let payload):
            print("cancelReservation(locked) -> unexpected success \(payload.reservationId)")
        case .fault(let fault):
            print("cancelReservation(locked) -> fault code=\(fault.detail?.code ?? "unknown") retryable=\(fault.detail?.retryable == true)")
        }
    }

    private static func runNIODemo() throws {
        let eventLoop = EmbeddedEventLoop()
        let server = NIOLoopbackServer()
        let registrar = ReservationDeskAgentPortNIOServerRegistrar(server: server)
        let implementation = NIOReservationService(ledger: ReservationLedger.demo())

        registrar.register(implementation: implementation)
        try server.start(on: eventLoop).wait()
        defer { _ = try? server.stop(on: eventLoop).wait() }

        let createResponse = try server.dispatch(
            ReservationDeskAgentPortCreateReservationOperation.self,
            request: CreateReservationRequestPayload(
                guestEmail: "grace@example.com",
                roomCode: "STE",
                arrivalDate: "2026-05-18",
                nights: 2
            ),
            on: eventLoop
        ).wait()

        let reservationId: String
        switch createResponse {
        case .success(let payload):
            reservationId = payload.reservationId
            print("createReservation -> success id=\(payload.reservationId) status=\(payload.status)")
        case .fault(let fault):
            print("createReservation -> unexpected fault \(fault.faultString)")
            return
        }

        let cancelResponse = try server.dispatch(
            ReservationDeskAgentPortCancelReservationOperation.self,
            request: CancelReservationRequestPayload(
                reservationId: reservationId,
                reason: "Switched to another property."
            ),
            on: eventLoop
        ).wait()

        switch cancelResponse {
        case .success(let payload):
            print("cancelReservation -> success at=\(payload.cancelledAt) refund=\(payload.refundAmount)")
        case .fault(let fault):
            print("cancelReservation -> unexpected fault \(fault.faultString)")
        }
    }
}

// These two conformances are the authoring surfaces produced by the server codegen.
private struct AsyncReservationService: ReservationDeskAgentPortAsyncService {
    let ledger: ReservationLedger

    func createReservation(
        request: CreateReservationRequestPayload
    ) async throws(any Error) -> SOAPOperationResponse<CreateReservationResponsePayload, ReservationProblemFaultDetail> {
        switch ledger.createReservation(
            guestEmail: request.guestEmail,
            roomCode: request.roomCode,
            arrivalDate: request.arrivalDate,
            nights: request.nights
        ) {
        case .success(let record):
            return .success(
                CreateReservationResponsePayload(
                    reservationId: record.id,
                    status: record.status,
                    quotedAmount: record.quotedAmount
                )
            )
        case .failure(let problem):
            return .fault(try makeReservationFault(problem))
        }
    }

    func appendReservationNote(
        request: AppendReservationNoteRequestPayload
    ) async throws(any Error) -> SOAPOperationResponse<AppendReservationNoteResponsePayload, SOAPEmptyFaultDetailPayload> {
        _ = ledger.appendReservationNote(
            reservationId: request.reservationId,
            author: request.author,
            note: request.note
        )
        return .success(AppendReservationNoteResponsePayload())
    }

    func getReservationTimeline(
        request: GetReservationTimelineRequestPayload
    ) async throws(any Error) -> SOAPOperationResponse<GetReservationTimelineResponsePayload, SOAPEmptyFaultDetailPayload> {
        let record = ledger.reservation(for: request.reservationId)
        let payload = GetReservationTimelineResponsePayload(
            reservationId: request.reservationId,
            status: record?.status ?? "missing",
            events: record?.events.map {
                ReservationTimelineEvent(
                    timestamp: $0.timestamp,
                    category: $0.category,
                    summary: $0.summary
                )
            }
        )
        return .success(payload)
    }

    func cancelReservation(
        request: CancelReservationRequestPayload
    ) async throws(any Error) -> SOAPOperationResponse<CancelReservationResponsePayload, ReservationProblemFaultDetail> {
        switch ledger.cancelReservation(reservationId: request.reservationId, reason: request.reason) {
        case .success(let cancellation):
            return .success(
                CancelReservationResponsePayload(
                    reservationId: cancellation.reservationId,
                    cancelledAt: cancellation.cancelledAt,
                    refundAmount: cancellation.refundAmount
                )
            )
        case .failure(let problem):
            return .fault(try makeReservationFault(problem))
        }
    }
}

private final class NIOReservationService: ReservationDeskAgentPortNIOService {
    let ledger: ReservationLedger

    init(ledger: ReservationLedger) {
        self.ledger = ledger
    }

    func createReservation(
        request: CreateReservationRequestPayload,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<SOAPOperationResponse<CreateReservationResponsePayload, ReservationProblemFaultDetail>> {
        switch ledger.createReservation(
            guestEmail: request.guestEmail,
            roomCode: request.roomCode,
            arrivalDate: request.arrivalDate,
            nights: request.nights
        ) {
        case .success(let record):
            return eventLoop.makeSucceededFuture(
                .success(
                    CreateReservationResponsePayload(
                        reservationId: record.id,
                        status: record.status,
                        quotedAmount: record.quotedAmount
                    )
                )
            )
        case .failure(let problem):
            do {
                return eventLoop.makeSucceededFuture(.fault(try makeReservationFault(problem)))
            } catch {
                return eventLoop.makeFailedFuture(error)
            }
        }
    }

    func appendReservationNote(
        request: AppendReservationNoteRequestPayload,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<SOAPOperationResponse<AppendReservationNoteResponsePayload, SOAPEmptyFaultDetailPayload>> {
        _ = ledger.appendReservationNote(
            reservationId: request.reservationId,
            author: request.author,
            note: request.note
        )
        return eventLoop.makeSucceededFuture(.success(AppendReservationNoteResponsePayload()))
    }

    func getReservationTimeline(
        request: GetReservationTimelineRequestPayload,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<SOAPOperationResponse<GetReservationTimelineResponsePayload, SOAPEmptyFaultDetailPayload>> {
        let record = ledger.reservation(for: request.reservationId)
        let payload = GetReservationTimelineResponsePayload(
            reservationId: request.reservationId,
            status: record?.status ?? "missing",
            events: record?.events.map {
                ReservationTimelineEvent(
                    timestamp: $0.timestamp,
                    category: $0.category,
                    summary: $0.summary
                )
            }
        )
        return eventLoop.makeSucceededFuture(.success(payload))
    }

    func cancelReservation(
        request: CancelReservationRequestPayload,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<SOAPOperationResponse<CancelReservationResponsePayload, ReservationProblemFaultDetail>> {
        switch ledger.cancelReservation(reservationId: request.reservationId, reason: request.reason) {
        case .success(let cancellation):
            return eventLoop.makeSucceededFuture(
                .success(
                    CancelReservationResponsePayload(
                        reservationId: cancellation.reservationId,
                        cancelledAt: cancellation.cancelledAt,
                        refundAmount: cancellation.refundAmount
                    )
                )
            )
        case .failure(let problem):
            do {
                return eventLoop.makeSucceededFuture(.fault(try makeReservationFault(problem)))
            } catch {
                return eventLoop.makeFailedFuture(error)
            }
        }
    }
}

private func makeReservationFault(_ problem: ReservationProblem) throws(SOAPCoreError) -> SOAPFault<ReservationProblemFaultDetail> {
    try SOAPFault(
        faultCode: .client,
        faultString: problem.message,
        detail: ReservationProblemFaultDetail(
            code: problem.code,
            message: problem.message,
            retryable: problem.retryable
        )
    )
}
