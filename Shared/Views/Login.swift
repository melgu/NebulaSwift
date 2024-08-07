//
//  Login.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 28.06.21.
//

import SwiftUI

struct Login: View {
	@EnvironmentObject private var api: API
	
	@State private var email = ""
	@State private var password = ""
	
	var body: some View {
		VStack {
			Text("Login")
				.font(.title)
			TextField("email", text: $email)
				.textContentType(.username)
				.autocorrectionDisabled()
				#if os(iOS)
				.keyboardType(.emailAddress)
				.textInputAutocapitalization(.never)
				#endif
			SecureField("password", text: $password)
				.onSubmit {
					try await api.login(email: email, password: password)
				}
			AsyncButton("Login") {
				try await api.login(email: email, password: password)
			}
			.buttonStyle(.bordered)
			.tint(.accentColor)
		}
		.textFieldStyle(.roundedBorder)
		.padding()
		.frame(width: 300)
	}
}

struct Login_Previews: PreviewProvider {
	static var previews: some View {
		Login()
			.environmentObject(API())
			.alertErrorHandling()
	}
}
