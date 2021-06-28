//
//  Login.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 28.06.21.
//

import SwiftUI

struct Login: View {
	@StateObject var model = Model()
	
	@Environment(\.presentationMode) var presentationMode
	
    var body: some View {
		VStack {
			Text("Login")
				.font(.title)
			TextField("email", text: $model.email)
			TextField("password", text: $model.password)
			Text(model.wrongCredentials ? "Wrong credentials" : " ")
				.foregroundColor(.red)
			Button {
				model.login(presentationMode: presentationMode)
			} label: {
				Text("Login")
			}
		}
		.padding()
		.frame(width: 300)
    }
}

extension Login {
	@MainActor class Model: ObservableObject {
		@Published var email = ""
		@Published var password = ""
		@Published var wrongCredentials = false
		
		func login(presentationMode: Binding<PresentationMode>) {
			wrongCredentials = false
			Task {
				do {
					Settings.shared.token = try await API.login(email: email, password: password)
					presentationMode.wrappedValue.dismiss()
				} catch {
					wrongCredentials = true
					show(error: error)
				}
			}
		}
		
		func show(error: Error) {
			print("Something went wrong:\n\(error)")
		}
	}
}

struct Login_Previews: PreviewProvider {
    static var previews: some View {
        Login()
    }
}
