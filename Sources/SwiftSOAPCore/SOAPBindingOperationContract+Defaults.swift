extension SOAPBindingOperationContract {
    public static var bindingMetadata: SOAPBindingMetadata {
        SOAPBindingMetadata(envelopeVersion: .soap11, style: .document, bodyUse: .literal)
    }

    public static func validateBinding() throws {
        let codecStrategy = SOAPBindingCodecFactory.makeCodecStrategy(for: bindingMetadata)
        try codecStrategy.validate(metadata: bindingMetadata)
    }
}
