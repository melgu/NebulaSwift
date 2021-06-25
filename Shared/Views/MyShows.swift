//
//  MyShows.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct MyShows: View {
    var body: some View {
		NavigationView {
			List {
				Text("My Shows")
			}
		}
    }
}

struct MyShows_Previews: PreviewProvider {
    static var previews: some View {
        MyShows()
    }
}
