//
//  Featured.swift
//  NebulaSwift
//
//  Created by Melvin Gundlach on 25.06.21.
//

import SwiftUI

struct Featured: View {
	@StateObject var model = Model()
	
    var body: some View {
		NavigationView {
			Text("Featured")
				.font(.title)
		}
    }
}

extension Featured {
	class Model: ObservableObject {
		
	}
}

struct Featured_Previews: PreviewProvider {
    static var previews: some View {
        Featured()
    }
}
