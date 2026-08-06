#if canImport(UIKit)
import SwiftUI

/// Eine wiederverwendbare SwiftUI-Komponente, die einen `LabeledContent` mit einem rechtsbündigen `TextField` kombiniert.
///
/// Verwendung:
/// ```swift
/// LabeledTextField("EODHD API-Key", text: $form.mandantEodhApiKey)
/// LabeledTextField("E-Mail", text: $form.mandantEmail, placeholder: "mail@example.com")
/// LabeledTextField("Telefon", text: $form.mandantTelefon, placeholder: "+41 44 000 00 00", keyboardType: .phonePad)
/// ```
public struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var tintColor: Color? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrection: Bool = true

    public var body: some View {
        LabeledContent(label) {
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .tint(tintColor)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(!autocorrection)
        }
    }
}

// MARK: - Convenience Initializers

extension LabeledTextField {
    /// Erstellt ein LabeledTextField mit lokalisierbarem Label
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, placeholder: String = "") {
        self.label = "\(titleKey)"
        self._text = text
        self.placeholder = placeholder
    }

    public init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        autocorrection: Bool = true,
        tintColor: Color? = nil
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.autocorrection = autocorrection
        self.tintColor = tintColor
    }

    public init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        tintColor: Color? = nil
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.tintColor = tintColor
    }
}

// MARK: - Preview

#Preview("LabeledTextField Examples") {
    Form {
        Section("Standard") {
            LabeledTextField("Firmenname", text: .constant("Muster AG"))
            LabeledTextField("API-Key", text: .constant(""))
        }

        Section("Mit Placeholder & Tint") {
            LabeledTextField(
                "E-Mail",
                text: .constant(""),
                placeholder: "mail@example.com",
                tintColor: .blue
            )
            LabeledTextField(
                "Telefon",
                text: .constant(""),
                placeholder: "+41 44 000 00 00",
                tintColor: .accentColor
            )
        }

        Section("Mit Keyboard-Typ (iOS)") {
            LabeledTextField(
                "E-Mail",
                text: .constant(""),
                placeholder: "mail@example.com",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never,
                autocorrection: false
            )
            LabeledTextField(
                "Telefon",
                text: .constant(""),
                placeholder: "+41 44 000 00 00",
                keyboardType: .phonePad,
                textContentType: .telephoneNumber
            )
            LabeledTextField(
                "PLZ",
                text: .constant(""),
                placeholder: "8001",
                keyboardType: .numberPad,
                textContentType: .postalCode
            )
        }
    }
}
#endif
