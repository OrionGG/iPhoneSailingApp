// Sources/App/MapView.swift
import SwiftUI
import MapKit

/// MapView wraps MKMapView to show current position and start waypoint with a bearing line.
struct MapView: UIViewRepresentable {
    @EnvironmentObject var locationManager: LocationManager

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.showsUserLocation = false // we manage annotation ourselves
        map.userTrackingMode = .none
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeAnnotations(uiView.annotations)
        uiView.removeOverlays(uiView.overlays)

        if let coord = locationManager.status.coordinate {
            let userAnn = MKPointAnnotation()
            userAnn.coordinate = coord
            userAnn.title = "You"
            uiView.addAnnotation(userAnn)
            // center map on user with a region
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 500, longitudinalMeters: 500)
            uiView.setRegion(region, animated: true)
        }

        if let wp = locationManager.startWaypoint {
            let wpAnn = MKPointAnnotation()
            wpAnn.coordinate = wp
            wpAnn.title = "Start"
            uiView.addAnnotation(wpAnn)
            // draw a line between current and waypoint
            if let coord = locationManager.status.coordinate {
                var coords = [coord, wp]
                let poly = MKPolyline(coordinates: &coords, count: 2)
                uiView.addOverlay(poly)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        init(_ parent: MapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: poly)
                r.strokeColor = UIColor.systemBlue
                r.lineWidth = 3
                r.alpha = 0.8
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

#if DEBUG
struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
            .environmentObject(LocationManager())
            .frame(height:300)
    }
}
#endif
