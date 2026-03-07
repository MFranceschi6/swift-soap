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
            targetNamespace="urn:weather"
            name="WeatherService">
          <wsdl:message name="GetWeatherInput">
            <wsdl:part name="city" type="xsd:string"/>
          </wsdl:message>
          <wsdl:message name="GetWeatherOutput">
            <wsdl:part name="temperature" type="xsd:int"/>
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
              <soap:operation soapAction="urn:weather#GetWeather"/>
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

        XCTAssertEqual(definition.messages.count, 2)
        XCTAssertEqual(definition.messages[0].name, "GetWeatherInput")
        XCTAssertEqual(definition.messages[0].parts.first?.name, "city")
        XCTAssertEqual(definition.messages[0].parts.first?.typeName, "string")

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
        XCTAssertEqual(definition.bindings[0].operations.first?.soapAction, "urn:weather#GetWeather")

        XCTAssertEqual(definition.services.count, 1)
        XCTAssertEqual(definition.services[0].name, "WeatherService")
        XCTAssertEqual(definition.services[0].ports.count, 1)
        XCTAssertEqual(definition.services[0].ports[0].name, "WeatherPort")
        XCTAssertEqual(definition.services[0].ports[0].bindingName, "WeatherBinding")
        XCTAssertEqual(definition.services[0].ports[0].address, "https://example.com/soap")
    }

    func test_parse_withoutDefinitionsRoot_throwsInvalidDocument() {
        let xml = "<root><service name=\"Invalid\"/></root>"

        let parser = WSDLDocumentParser()
        XCTAssertThrowsError(try parser.parse(data: Data(xml.utf8))) { error in
            guard case WSDLParsingError.invalidDocument = error else {
                return XCTFail("Expected invalidDocument, got: \(error)")
            }
        }
    }

    func test_parse_operationWithoutName_throwsInvalidOperation() {
        let wsdl = """
        <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/">
          <wsdl:portType name="WeatherPortType">
            <wsdl:operation>
              <wsdl:input message="tns:GetWeatherInput"/>
            </wsdl:operation>
          </wsdl:portType>
        </wsdl:definitions>
        """

        let parser = WSDLDocumentParser()
        XCTAssertThrowsError(try parser.parse(data: Data(wsdl.utf8))) { error in
            guard case WSDLParsingError.invalidOperation = error else {
                return XCTFail("Expected invalidOperation, got: \(error)")
            }
        }
    }

    func test_parse_messageWithoutName_throwsInvalidMessage() {
        let wsdl = """
        <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/">
          <wsdl:message>
            <wsdl:part name="city" type="xsd:string"/>
          </wsdl:message>
        </wsdl:definitions>
        """

        let parser = WSDLDocumentParser()
        XCTAssertThrowsError(try parser.parse(data: Data(wsdl.utf8))) { error in
            guard case WSDLParsingError.invalidMessage = error else {
                return XCTFail("Expected invalidMessage, got: \(error)")
            }
        }
    }

    func test_parse_bindingWithoutName_throwsInvalidBinding() {
        let wsdl = """
        <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/">
          <wsdl:binding type="tns:WeatherPortType">
            <wsdl:operation name="GetWeather"/>
          </wsdl:binding>
        </wsdl:definitions>
        """

        let parser = WSDLDocumentParser()
        XCTAssertThrowsError(try parser.parse(data: Data(wsdl.utf8))) { error in
            guard case WSDLParsingError.invalidBinding = error else {
                return XCTFail("Expected invalidBinding, got: \(error)")
            }
        }
    }

    func test_parse_servicePortWithoutName_throwsInvalidServicePort() {
        let wsdl = """
        <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/">
          <wsdl:service name="WeatherService">
            <wsdl:port binding="tns:WeatherBinding"/>
          </wsdl:service>
        </wsdl:definitions>
        """

        let parser = WSDLDocumentParser()
        XCTAssertThrowsError(try parser.parse(data: Data(wsdl.utf8))) { error in
            guard case WSDLParsingError.invalidServicePort = error else {
                return XCTFail("Expected invalidServicePort, got: \(error)")
            }
        }
    }
}
