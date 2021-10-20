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
				.textContentType(.username)
				#if os(iOS)
				.keyboardType(.emailAddress)
				#endif
			TextField("password", text: $password)
				.textContentType(.password)
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
