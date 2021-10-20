//
//  Login.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 28.06.21.
//

import SwiftUI

struct Login: View {
	@EnvironmentObject var api: API
	
	@State var email = ""
	@State var password = ""
	@State var wrongCredentials = false
	
    var body: some View {
		VStack {
			Text("Login")
				.font(.title)
			TextField("email", text: $email)
				#if os(iOS)
				// .textContentType works on macOS, but creates a weird box when typing. TODO: Beta bug?
				.textContentType(.username)
				.keyboardType(.emailAddress)
				#endif
			SecureField("password", text: $password, prompt: Text("Ladida"))
			Text(wrongCredentials ? "Wrong credentials" : " ")
				.foregroundColor(.red)
			Button {
				wrongCredentials = false
				Task {
					do {
						try await api.login(email: email, password: password)
					} catch {
						print(error)
						wrongCredentials = true
					}
				}
			} label: {
				Text("Login")
			}
		}
		.padding()
		.frame(width: 300)
    }
}

struct Login_Previews: PreviewProvider {
    static var previews: some View {
        Login()
    }
}
