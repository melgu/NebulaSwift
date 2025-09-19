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
	@State private var isInProgress = false
	
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
				.onSubmit(login)
			
			AsyncButton("Login", action: login)
				.buttonStyle(.bordered)
				.tint(.accentColor)
		}
		.disabled(isInProgress)
		.textFieldStyle(.roundedBorder)
		.padding()
		.frame(width: 300)
	}
	
	private func login() async throws {
		isInProgress = true
		defer { isInProgress = false }
		try await api.login(email: email, password: password)
	}
}

struct Login_Previews: PreviewProvider {
	static var previews: some View {
		Login()
			.environmentObject(API())
			.alertErrorHandling()
	}
}
