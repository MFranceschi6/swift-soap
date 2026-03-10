extension SOAPOperationContract {
    /// Default `soapAction` implementation: returns `nil`.
    ///
    /// Override this in your operation type when the service requires a `SOAPAction`
    /// HTTP header (typical for SOAP 1.1 services generated from WSDL).
    public static var soapAction: SOAPAction? {
        nil
    }
}
