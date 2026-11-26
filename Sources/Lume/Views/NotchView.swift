import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchModel
    let canvasSize: CGSize

    var body: some View {
        let flare = NotchCurve.flare(forHeight: model.size.height)
        NotchShape(topRadius: flare, bottomRadius: NotchCurve.cornerRadius(forHeight: model.size.height))
            .fill(.black)
            .frame(width: model.size.width + flare * 2, height: model.size.height)
            .frame(width: canvasSize.width, height: canvasSize.height, alignment: .top)
    }
}
