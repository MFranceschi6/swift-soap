# ReservationDeskServerExample

Runnable example focused on the generated server authoring surface.

It shows:
- an async server implementation conforming to the generated `...AsyncService` protocol
- a NIO server implementation conforming to the generated `...NIOService` protocol
- multiple operations with different shapes:
  - typed business response
  - empty business response
  - typed SOAP fault

Run it from the example directory with:

```bash
cd Examples/ReservationDeskServerExample
swift run ReservationDeskServerExample
```

The main implementation lives in:
- `Examples/ReservationDeskServerExample/Sources/ReservationDeskServerExample/ReservationDeskServerExample.swift`
- `Examples/ReservationDeskServerExample/Sources/ReservationDeskServerExample/LoopbackSupport.swift`

The SOAP contract is generated at build time from:
- `Examples/ReservationDeskServerExample/WSDL/reservation-desk.wsdl`
