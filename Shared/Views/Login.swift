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
	@State private var wrongCredentials = false
	
    var body: some View {
		VStack {
			Text("Login")
				.font(.title)
			TextField("email", text: $email)
				.textContentType(.username)
				#if os(iOS)
				.keyboardType(.emailAddress)
				#endif
			SecureField("password", text: $password)
			Text(wrongCredentials ? "Wrong credentials" : " ")
				.foregroundColor(.red)
			AsyncButton("Login") {
				wrongCredentials = false
				do {
					try await api.login(email: email, password: password)
				} catch {
					print(error)
					wrongCredentials = true
				}
			}
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
