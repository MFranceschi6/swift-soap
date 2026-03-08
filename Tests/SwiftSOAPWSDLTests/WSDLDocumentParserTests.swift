import Foundation
import SwiftSOAPWSDL
import XCTest

final class WSDLDocumentParserTests: XCTestCase {
    func test_parse_withDocumentLiteral_extractsCoreDefinitions() throws {
        let wsdl = """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
            xmlns:tns="urn:weather"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:weather"
            name="WeatherService">
          <wsdl:types>
            <xsd:schema targetNamespace="urn:weather">
              <xsd:complexType name="WeatherResult">
                <xsd:sequence>
                  <xsd:element name="temperature" type="xsd:int"/>
                </xsd:sequence>
              </xsd:complexType>
              <xsd:element name="WeatherRequestElement" type="xsd:string"/>
            </xsd:schema>
          </wsdl:types>
          <wsdl:message name="GetWeatherInput">
            <wsdl:part name="city" type="xsd:string"/>
          </wsdl:message>
          <wsdl:message name="GetWeatherOutput">
            <wsdl:part name="temperature" type="xsd:int"/>
          </wsdl:message>
          <wsdl:message name="ServiceFaultMessage">
            <wsdl:part name="detail" type="xsd:string"/>
          </wsdl:message>
          <wsdl:portType name="WeatherPortType">
            <wsdl:operation name="GetWeather">
              <wsdl:input message="tns:GetWeatherInput"/>
              <wsdl:output message="tns:GetWeatherOutput"/>
              <wsdl:fault name="ServiceFault" message="tns:ServiceFaultMessage"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="WeatherBinding" type="tns:WeatherPortType">
            <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
            <wsdl:operation name="GetWeather">
              <soap:operation soapAction="urn:weather#GetWeather" style="document"/>
              <wsdl:input>
                <soap:body use="literal"/>
              </wsdl:input>
              <wsdl:output>
                <soap:body use="literal"/>
              </wsdl:output>
            </wsdl:operation>
          </wsdl:binding>
          <wsdl:service name="WeatherService">
            <wsdl:port name="WeatherPort" binding="tns:WeatherBinding">
              <soap:address location="https://example.com/soap"/>
            </wsdl:port>
          </wsdl:service>
        </wsdl:definitions>
        """

        let parser = WSDLDocumentParser()
        let definition = try parser.parse(data: Data(wsdl.utf8))

        XCTAssertEqual(definition.name, "WeatherService")
        XCTAssertEqual(definition.targetNamespace, "urn:weather")

        XCTAssertEqual(definition.types.schemas.count, 1)
        XCTAssertEqual(definition.types.schemas[0].complexTypes[0].name, "WeatherResult")

        XCTAssertEqual(definition.messages.count, 3)
        XCTAssertEqual(definition.messages[0].name, "GetWeatherInput")
        XCTAssertEqual(definition.messages[0].parts.first?.name, "city")
        XCTAssertEqual(definition.messages[0].parts.first?.typeName, "string")
        XCTAssertEqual(
            definition.messages[0].parts.first?.typeQName?.namespaceURI,
            "http://www.w3.org/2001/XMLSchema"
        )

        XCTAssertEqual(definition.portTypes.count, 1)
        XCTAssertEqual(definition.portTypes[0].name, "WeatherPortType")
        XCTAssertEqual(definition.portTypes[0].operations.count, 1)
        XCTAssertEqual(definition.portTypes[0].operations[0].name, "GetWeather")
        XCTAssertEqual(definition.portTypes[0].operations[0].inputMessageName, "GetWeatherInput")
        XCTAssertEqual(definition.portTypes[0].operations[0].outputMessageName, "GetWeatherOutput")

        XCTAssertEqual(definition.bindings.count, 1)
        XCTAssertEqual(definition.bindings[0].name, "WeatherBinding")
        XCTAssertEqual(definition.bindings[0].typeName, "WeatherPortType")
        XCTAssertEqual(definition.bindings[0].style, "document")
        XCTAssertEqual(definition.bindings[0].soapVersion, .soap11)
        XCTAssertEqual(definition.bindings[0].styleKind, .document)
        XCTAssertEqual(definition.bindings[0].operations.first?.soapAction, "urn:weather#GetWeather")
        XCTAssertEqual(definition.bindings[0].operations.first?.style, "document")
        XCTAssertEqual(definition.bindings[0].operations.first?.inputUse, "literal")
        XCTAssertEqual(definition.bindings[0].operations.first?.outputUse, "literal")

        XCTAssertEqual(definition.services.count, 1)
        XCTAssertEqual(definition.services[0].name, "WeatherService")
        XCTAssertEqual(definition.services[0].ports.count, 1)
        XCTAssertEqual(definition.services[0].ports[0].name, "WeatherPort")
        XCTAssertEqual(definition.services[0].ports[0].bindingName, "WeatherBinding")
        XCTAssertEqual(definition.services[0].ports[0].address, "https://example.com/soap")
    }

    func test_parse_withSOAP12RPCEncoded_extractsBindingMetadata() throws {
        let wsdl = """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:soap12="http://schemas.xmlsoap.org/wsdl/soap12/"
            xmlns:tns="urn:calc"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:calc">
          <wsdl:message name="AddInput">
            <wsdl:part name="left" type="xsd:int"/>
          </wsdl:message>
          <wsdl:message name="AddOutput">
            <wsdl:part name="result" type="xsd:int"/>
          </wsdl:message>
          <wsdl:portType name="CalcPortType">
            <wsdl:operation name="Add">
              <wsdl:input message="tns:AddInput"/>
              <wsdl:output message="tns:AddOutput"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="CalcBinding" type="tns:CalcPortType">
            <soap12:binding style="rpc" transport="http://schemas.xmlsoap.org/soap/http"/>
            <wsdl:operation name="Add">
              <soap12:operation soapAction="urn:add" style="rpc"/>
              <wsdl:input><soap12:body use="encoded"/></wsdl:input>
              <wsdl:output><soap12:body use="encoded"/></wsdl:output>
            </wsdl:operation>
          </wsdl:binding>
        </wsdl:definitions>
        """

        let definition = try WSDLDocumentParser().parse(data: Data(wsdl.utf8))
        let binding = try XCTUnwrap(definition.bindings.first)

        XCTAssertEqual(binding.soapVersion, .soap12)
        XCTAssertEqual(binding.styleKind, .rpc)
        XCTAssertEqual(binding.operations.first?.styleKind, .rpc)
        XCTAssertEqual(binding.operations.first?.inputUseKind, .encoded)
        XCTAssertEqual(binding.operations.first?.outputUseKind, .encoded)
    }

    func test_parse_typesWithChoiceAndAttributes_extractsSchemaModel() throws {
        let wsdl = """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:types">
          <wsdl:types>
            <xsd:schema targetNamespace="urn:types">
              <xsd:complexType name="Order">
                <xsd:sequence>
                  <xsd:element name="id" type="xsd:string" minOccurs="1"/>
                </xsd:sequence>
                <xsd:choice>
                  <xsd:element name="couponCode" type="xsd:string" minOccurs="0"/>
                </xsd:choice>
                <xsd:attribute name="source" type="xsd:string" use="required"/>
              </xsd:complexType>
              <xsd:simpleType name="OrderStatus">
                <xsd:restriction base="xsd:string">
                  <xsd:enumeration value="pending"/>
                  <xsd:enumeration value="shipped"/>
                </xsd:restriction>
              </xsd:simpleType>
            </xsd:schema>
          </wsdl:types>
        </wsdl:definitions>
        """

        let definition = try WSDLDocumentParser().parse(data: Data(wsdl.utf8))
        let schema = try XCTUnwrap(definition.types.schemas.first)

        XCTAssertEqual(schema.complexTypes.count, 1)
        XCTAssertEqual(schema.complexTypes[0].sequence.first?.name, "id")
        XCTAssertEqual(schema.complexTypes[0].choice.first?.name, "couponCode")
        XCTAssertEqual(schema.complexTypes[0].attributes.first?.name, "source")

        XCTAssertEqual(schema.simpleTypes.count, 1)
        XCTAssertEqual(schema.simpleTypes[0].name, "OrderStatus")
        XCTAssertEqual(schema.simpleTypes[0].enumerationValues, ["pending", "shipped"])
    }

    func test_parse_withLocalSchemaInclude_loadsIncludedSchema() throws {
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectoryURL) }

        let includeFileURL = temporaryDirectoryURL.appendingPathComponent("shared-types.xsd")
        try """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:inc">
          <xsd:complexType name="IncludedType">
            <xsd:sequence>
              <xsd:element name="value" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """.write(to: includeFileURL, atomically: true, encoding: .utf8)

        let wsdl = """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:inc">
          <wsdl:types>
            <xsd:schema targetNamespace="urn:inc">
              <xsd:include schemaLocation="shared-types.xsd"/>
            </xsd:schema>
          </wsdl:types>
        </wsdl:definitions>
        """

        let wsdlURL = temporaryDirectoryURL.appendingPathComponent("service.wsdl")
        let parser = WSDLDocumentParser()
        let definition = try parser.parse(data: Data(wsdl.utf8), sourceURL: wsdlURL)

        XCTAssertGreaterThanOrEqual(definition.types.schemas.count, 2)
        XCTAssertTrue(definition.types.schemas.contains(where: { schema in
            schema.complexTypes.contains(where: { $0.name == "IncludedType" })
        }))
    }

    func test_parse_withUnknownQNamePrefix_throwsInvalidDocument() {
        let wsdl = """
        <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/">
          <wsdl:portType name="WeatherPortType">
            <wsdl:operation name="GetWeather">
              <wsdl:input message="tns:UnknownInput"/>
            </wsdl:operation>
          </wsdl:portType>
        </wsdl:definitions>
        """

        XCTAssertThrowsError(try WSDLDocumentParser().parse(data: Data(wsdl.utf8))) { error in
            guard case WSDLParsingError.invalidDocument = error else {
                return XCTFail("Expected invalidDocument, got: \(error)")
            }
        }
    }

    func test_parse_withoutDefinitionsRoot_throwsInvalidDocument() {
        let xml = "<root><service name=\"Invalid\"/></root>"

        XCTAssertThrowsError(try WSDLDocumentParser().parse(data: Data(xml.utf8))) { error in
            guard case WSDLParsingError.invalidDocument = error else {
                return XCTFail("Expected invalidDocument, got: \(error)")
            }
        }
    }

    func test_parse_bindingOperationNotInPortType_throwsInvalidBinding() {
        let wsdl = """
        <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:tns="urn:test">
          <wsdl:message name="GetWeatherInput"/>
          <wsdl:portType name="WeatherPortType">
            <wsdl:operation name="GetWeather">
              <wsdl:input message="tns:GetWeatherInput"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="WeatherBinding" type="tns:WeatherPortType">
            <wsdl:operation name="NotDeclaredOnPortType"/>
          </wsdl:binding>
        </wsdl:definitions>
        """

        XCTAssertThrowsError(try WSDLDocumentParser().parse(data: Data(wsdl.utf8))) { error in
            guard case WSDLParsingError.invalidBinding = error else {
                return XCTFail("Expected invalidBinding, got: \(error)")
            }
        }
    }

    func test_parse_servicePortWithUnknownBinding_throwsInvalidServicePort() {
        let wsdl = """
        <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:tns="urn:test">
          <wsdl:service name="WeatherService">
            <wsdl:port name="WeatherPort" binding="tns:UnknownBinding"/>
          </wsdl:service>
        </wsdl:definitions>
        """

        XCTAssertThrowsError(try WSDLDocumentParser().parse(data: Data(wsdl.utf8))) { error in
            guard case WSDLParsingError.invalidServicePort = error else {
                return XCTFail("Expected invalidServicePort, got: \(error)")
            }
        }
    }

    func test_parse_bindingWithInvalidInputUse_throwsInvalidBinding() {
        let wsdl = """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
            xmlns:tns="urn:test">
          <wsdl:message name="GetWeatherInput"/>
          <wsdl:portType name="WeatherPortType">
            <wsdl:operation name="GetWeather">
              <wsdl:input message="tns:GetWeatherInput"/>
            </wsdl:operation>
          </wsdl:portType>
          <wsdl:binding name="WeatherBinding" type="tns:WeatherPortType">
            <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
            <wsdl:operation name="GetWeather">
              <wsdl:input>
                <soap:body use="invalid-use"/>
              </wsdl:input>
            </wsdl:operation>
          </wsdl:binding>
        </wsdl:definitions>
        """

        XCTAssertThrowsError(try WSDLDocumentParser().parse(data: Data(wsdl.utf8))) { error in
            guard case WSDLParsingError.invalidBinding = error else {
                return XCTFail("Expected invalidBinding, got: \(error)")
            }
        }
    }

    func test_parse_simpleTypeWithXSDFacets_populatesFacets() throws {
        let wsdl = """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:test">
          <wsdl:types>
            <xsd:schema targetNamespace="urn:test">
              <xsd:simpleType name="PostalCode">
                <xsd:restriction base="xsd:string">
                  <xsd:minLength value="4"/>
                  <xsd:maxLength value="6"/>
                  <xsd:pattern value="[0-9]+"/>
                </xsd:restriction>
              </xsd:simpleType>
            </xsd:schema>
          </wsdl:types>
        </wsdl:definitions>
        """

        let definition = try WSDLDocumentParser().parse(data: Data(wsdl.utf8))
        let schema = try XCTUnwrap(definition.types.schemas.first)
        let simpleType = try XCTUnwrap(schema.simpleTypes.first)

        XCTAssertEqual(simpleType.name, "PostalCode")
        let facets = try XCTUnwrap(simpleType.facets)
        XCTAssertEqual(facets.minLength, 4)
        XCTAssertEqual(facets.maxLength, 6)
        XCTAssertEqual(facets.pattern, "[0-9]+")
        XCTAssertNil(facets.minInclusive)
        XCTAssertNil(facets.maxInclusive)
    }

    func test_parse_simpleTypeWithEnumerationFacets_populatesFacetsAndEnumerationValues() throws {
        let wsdl = """
        <wsdl:definitions
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            targetNamespace="urn:test">
          <wsdl:types>
            <xsd:schema targetNamespace="urn:test">
              <xsd:simpleType name="Priority">
                <xsd:restriction base="xsd:string">
                  <xsd:enumeration value="low"/>
                  <xsd:enumeration value="medium"/>
                  <xsd:enumeration value="high"/>
                </xsd:restriction>
              </xsd:simpleType>
            </xsd:schema>
          </wsdl:types>
        </wsdl:definitions>
        """

        let definition = try WSDLDocumentParser().parse(data: Data(wsdl.utf8))
        let schema = try XCTUnwrap(definition.types.schemas.first)
        let simpleType = try XCTUnwrap(schema.simpleTypes.first)

        XCTAssertEqual(simpleType.name, "Priority")
        XCTAssertEqual(simpleType.enumerationValues, ["low", "medium", "high"])
        let facets = try XCTUnwrap(simpleType.facets)
        XCTAssertEqual(facets.enumeration, ["low", "medium", "high"])
    }
}
