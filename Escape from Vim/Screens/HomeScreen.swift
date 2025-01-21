import SwiftUI
import MapKit
import CoreLocation

extension CLLocationCoordinate2D {
    func isEqual(to other: CLLocationCoordinate2D, tolerance: Double = 0.0001) -> Bool {
        abs(latitude - other.latitude) < tolerance && abs(longitude - other.longitude) < tolerance
    }
}

extension MKCoordinateRegion {
    init(routes: [[CLLocationCoordinate2D]]) {
        guard !routes.isEmpty else {
            self = MKCoordinateRegion()
            return
        }

        var minLat = routes[0][0].latitude
        var maxLat = routes[0][0].latitude
        var minLon = routes[0][0].longitude
        var maxLon = routes[0][0].longitude

        for route in routes {
            for coordinate in route {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLon = min(minLon, coordinate.longitude)
                maxLon = max(maxLon, coordinate.longitude)
            }
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )

        self = MKCoordinateRegion(center: center, span: span)
    }
}

struct MapView: UIViewRepresentable {
    var routes: [[CLLocationCoordinate2D]]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)

        for route in routes {
            if !route.isEmpty {
                let polyline = MKPolyline(coordinates: route, count: route.count)
                uiView.addOverlay(polyline)
            }
        }

        // Устанавливаем регион карты, чтобы охватить весь маршрут
        if let firstRoute = routes.first, !firstRoute.isEmpty {
            let region = MKCoordinateRegion(routes: routes)
            uiView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// Кастомная карта для отображения маршрута
struct CustomMapView: UIViewRepresentable {
    @Binding var routes: [[CLLocationCoordinate2D]]
    @Binding var mapRegion: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)

        for (index, route) in routes.enumerated() where !route.isEmpty {
            let polyline = MKPolyline(coordinates: route, count: route.count)
            uiView.addOverlay(polyline)
            print("Добавлена полилиния маршрута \(index): \(route.count) точек.")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CustomMapView

        init(_ parent: CustomMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.mapRegion = mapView.region
        }
    }
}

// Главный экран с вкладками
struct HomePage: View {
    var body: some View {
        TabView {
            ActivitiesView()
                .tabItem {
                    Label("Активности", systemImage: "figure.walk")
                }

            ProfileView()
                .tabItem {
                    Label("Профиль", systemImage: "person.circle")
                }
        }
    }
}

// Экран с активностями
struct ActivitiesView: View {
    @State private var selectedActivity: String? = nil
        @State private var isTracking: Bool = false
        @State private var isRunning: Bool = false
        @State private var timer: Timer?
        @State private var secondsElapsed: Int = 0
        @State private var distanceTraveled: Double = 0
        @State private var route: [CLLocationCoordinate2D] = []
        @State private var isPaused: Bool = false
        @State private var routes: [[CLLocationCoordinate2D]] = []
        @State private var activities: [Activity] = []
        @StateObject private var locationManager = LocationManager()
        @State private var lastLocationBeforePause: CLLocationCoordinate2D? = nil
        @State private var lastUpdateTime: Date = Date()
        @State private var mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        @AppStorage("currentUserId") var currentUserId: Int?

    var body: some View {
            NavigationView {
                VStack {
                    if !isTracking {
                        Text("Активности")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, -35)
                    }

                    if isTracking {
                        ZStack(alignment: .bottom) {
                            CustomMapView(routes: $routes, mapRegion: $mapRegion)
                                .ignoresSafeArea()

                            if selectedActivity == nil {
                                bottomPanelNoActivity
                            } else {
                                bottomPanelActivity
                            }
                        }
                    } else {
                        contentWhenNotTracking
                    }
                }
                .navigationBarBackButtonHidden(true)
                .navigationBarHidden(isTracking)
                .toolbar(isTracking ? .hidden : .visible, for: .tabBar)
                .onAppear {
                    if let userId = currentUserId {
                        activities = DatabaseManager.shared.loadActivities(for: Int64(userId))
                    }
                }
                .onReceive(locationManager.$location) { location in
                    if let location = location {
                        mapRegion = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    }
                }
            }
        }

    private func groupActivitiesByDate() -> [String: [Activity]] {
        let groupedActivities = Dictionary(grouping: activities) { activity in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            return dateFormatter.string(from: activity.date)
        }
        return groupedActivities
    }

    private var contentWhenNotTracking: some View {
        VStack {
            if activities.isEmpty {
                emptyActivityView
            } else {
                List {
                    ForEach(groupActivitiesByDate().keys.sorted(by: >), id: \.self) { date in
                        Section(header: Text(date).font(.headline)) {
                            ForEach(groupActivitiesByDate()[date]!) { activity in
                                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                    HStack {
                                        Image(systemName: activity.type == "Велосипед" ? "bicycle" : "figure.walk")
                                            .resizable()
                                            .frame(width: 30, height: 30)
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading) {
                                            Text("\(activity.distance, specifier: "%.2f") км")
                                                .font(.headline)
                                            Text(activity.type)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text(activity.date, style: .time)
                                            .font(.footnote)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                }
                Spacer()
                Button(action: startNewActivity) {
                    Text("Начать новую активность")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding()
            }
        }
    }

    private var emptyActivityView: some View {
        VStack {
            Spacer()
            Text("Время потренить")
                .font(.title2)
                .fontWeight(.bold)
            Text("Нажимай на кнопку ниже и начинаем трекать активность")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button(action: startNewActivity) {
                Text("Начать активность")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    private func startNewActivity() {
        resetActivity()
        isTracking = true

        if let userId = currentUserId {
            activities = DatabaseManager.shared.loadActivities(for: Int64(userId))
        }

        locationManager.startTracking { newLocation in
            guard let newLocation = newLocation else {
                print("Не удалось получить новое местоположение.")
                return
            }

            if isPaused {
                return
            }

            // Новый маршрут
            if route.isEmpty {
                route = [newLocation.coordinate]
                routes = [route]
                mapRegion.center = newLocation.coordinate
                updateMapView()
                print("Начальная точка маршрута добавлена: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
            } else if isRunning {
                let distance = calculateDistance(newLocation: newLocation)
                distanceTraveled += distance
                route.append(newLocation.coordinate)
                routes[routes.count - 1] = route
                mapRegion.center = newLocation.coordinate
                updateMapView()
                print("Добавлена точка маршрута: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
            }
        }
    }

    private func updateMapView() {
        DispatchQueue.main.async {
            print("Обновление карты: маршрутов \(self.routes.count), текущий маршрут содержит \(self.route.count) точек.")
            self.routes = self.routes
        }
    }

    // Панель внизу, если ещё не выбрана активность
    private var bottomPanelNoActivity: some View {
        VStack(spacing: 16) {
            Text("Погнали? :)")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 18)

            HStack(spacing: 16) {
                Button(action: {
                    selectedActivity = "Велосипед"
                    isRunning = true
                    startTimer()
                }) {
                    VStack {
                        Image(systemName: "bicycle")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.blue)
                        Text("Велосипед")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.4), radius: 4, x: 0, y: 2)
                }

                Button(action: {
                    selectedActivity = "Бег"
                    isRunning = true
                    startTimer()
                }) {
                    VStack {
                        Image(systemName: "figure.walk")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.green)
                        Text("Бег")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.4), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 45)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.95))
        .cornerRadius(20)
        .padding(.bottom, -35)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // Панель внизу, если активность уже идёт
    private var bottomPanelActivity: some View {
        VStack(spacing: 8) {
            Text("\(selectedActivity ?? "активность")")
                .font(.headline)
                .padding(.top, 18)

            Text("\(distanceTraveled, specifier: "%.2f")км")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(formatTime(secondsElapsed))
                .font(.headline)

            HStack(spacing: 24) {
                Button(action: toggleRunning) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(isRunning ? Color.blue : Color.green)
                        .clipShape(Circle())
                }

                Button(action: stopActivity) {
                    Image(systemName: "flag.checkered")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 45)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.95))
        .cornerRadius(20)
        .padding(.bottom, -35)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: - Логика работы таймера, расчёты

    private func toggleRunning() {
        if isRunning {
            isPaused = true
            stopTimer()
            print("Пауза: сохранена последняя точка маршрута \(String(describing: lastLocationBeforePause))")
        } else {
            isPaused = false
            startTimer()

            // Начинаем новый сегмент маршрута
            if let lastPausedLocation = lastLocationBeforePause {
                startNewSegment(from: lastPausedLocation)
            } else if let currentLocation = locationManager.location?.coordinate {
                startNewSegment(from: currentLocation)
            }
        }
        isRunning.toggle()
    }

    private func startNewSegment(from coordinate: CLLocationCoordinate2D? = nil) {
        guard let startCoordinate = coordinate ?? lastLocationBeforePause else {
            print("Ошибка: начальная точка сегмента отсутствует.")
            return
        }
        route = [startCoordinate]
        routes.append(route)
        updateMapView()
        print("Создан новый сегмент маршрута с началом в точке \(startCoordinate). Маршрутов сейчас: \(routes.count).")
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            secondsElapsed += 1
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func stopActivity() {
        stopTimer()
        isTracking = false
        locationManager.stopTracking()
        isRunning = false
        isPaused = false

        let newActivity = Activity(
            id: 0,
            type: selectedActivity ?? "Активность",
            distance: distanceTraveled,
            duration: formatTime(secondsElapsed),
            date: Date(),
            routes: routes,
            comment: ""
        )

        // Сохраняем активность в базу данных
        if let userId = currentUserId {
            DatabaseManager.shared.saveActivity(activity: newActivity, userId: Int64(userId))
        }

        // Обновляем массив activities из базы данных
        if let userId = currentUserId {
            activities = DatabaseManager.shared.loadActivities(for: Int64(userId))
        }

        resetActivity()
    }
    
    private func resetActivity() {
        selectedActivity = nil
        route.removeAll()
        routes.removeAll()
        distanceTraveled = 0
        secondsElapsed = 0
        isRunning = false
        lastLocationBeforePause = nil
        print("Все данные активности сброшены.")
    }

    private func calculateDistance(newLocation: CLLocation) -> Double {
        guard let lastLocation = route.last else {
            print("Первая точка маршрута, расстояние 0.")
            return 0
        }

        let lastCLLocation = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
        let distance = lastCLLocation.distance(from: newLocation) / 1000
        print("Расстояние между точками: \(distance) км.")
        return distance
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

// Структура данных активности
struct Activity: Identifiable {
    let id: Int64
    let type: String
    let distance: Double
    let duration: String
    let date: Date
    let routes: [[CLLocationCoordinate2D]]
    var comment: String
}

// Точка маршрута
struct RoutePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// Класс локации
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation? // Add this line

    private var locationManager = CLLocationManager()
    private var updateHandler: ((CLLocation?) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.distanceFilter = 10
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func startTracking(updateHandler: @escaping (CLLocation?) -> Void) {
        self.updateHandler = updateHandler
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        updateHandler = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        DispatchQueue.main.async {
            self.updateHandler?(location)
        }
    }
}

// Экран детальной информации по активности
struct ActivityDetailView: View {
    @State private var comment: String
    let activity: Activity

    init(activity: Activity) {
        self.activity = activity
        self._comment = State(initialValue: activity.comment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(activity.date, style: .time)
                    .font(.headline)
                Spacer()
                Text(activity.type)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(activity.distance, specifier: "%.2f") км")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("\(timeSinceActivity(activity.date)) назад")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)

            HStack {
                Text("Старт \(activity.date, style: .time)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
                Text("Финиш \(activity.date.addingTimeInterval(durationStringToTimeInterval(activity.duration)), style: .time)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)

            MapView(routes: activity.routes)
                .frame(height: 200)
                .cornerRadius(12)
                .padding(.horizontal)

            TextField("Добавить комментарий", text: $comment)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            Button(action: saveComment) {
                Text("Сохранить комментарий")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
        .navigationTitle("Детали активности")
        .navigationBarTitleDisplayMode(.inline)
    }

    // Сохранение комментария
    private func saveComment() {
        var updatedActivity = activity
        updatedActivity.comment = comment
        DatabaseManager.shared.updateActivity(activity: updatedActivity)
    }

    // Расчет времени, прошедшего с момента активности
    private func timeSinceActivity(_ date: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]
        formatter.maximumUnitCount = 1

        let timeInterval = Date().timeIntervalSince(date)
        return formatter.string(from: timeInterval) ?? "Недавно"
    }

    // Преобразование строки duration в TimeInterval
    private func durationStringToTimeInterval(_ duration: String) -> TimeInterval {
        let components = duration.components(separatedBy: ":")
        guard components.count == 3,
              let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return 0
        }
        return hours * 3600 + minutes * 60 + seconds
    }
}



struct SimpleLineChart: View {
    let data: [Double]
    let labels: [String]

    private var maxValue: Double {
        let max = data.max() ?? 1.0
        return max > 0 ? max : 1.0
    }

    var body: some View {
        VStack {
            // График
            chartView
                .frame(height: 100)
                .clipped()
                .background(Color.white.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            // Подписи по оси X
            HStack(spacing: 0) {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption)
                        .frame(width: (UIScreen.main.bounds.width - 40) / CGFloat(labels.count), alignment: .center)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding()
    }

    // Компонент для отображения графика
    private var chartView: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<Int(maxValue) + 1, id: \.self) { km in
                    let y = CGFloat(1 - Double(km) / maxValue) * geometry.size.height
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }

                // Линии, соединяющие точки
                Path { path in
                    let spacing: CGFloat = geometry.size.width / CGFloat(data.count - 1)
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * spacing
                        let y = CGFloat(1 - (value / maxValue)) * geometry.size.height 
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)

                // Точки на графике
                ForEach(Array(zip(data, labels)), id: \.1) { value, label in
                    let index = data.firstIndex(where: { $0 == value })!
                    let spacing: CGFloat = geometry.size.width / CGFloat(data.count - 1)
                    let x = CGFloat(index) * spacing
                    let y = CGFloat(1 - (value / maxValue)) * geometry.size.height
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                }

                // Отметки по километрам на вертикальной оси
                ForEach(0..<Int(maxValue) + 1, id: \.self) { km in
                    let y = CGFloat(1 - Double(km) / maxValue) * geometry.size.height
                    Text("\(km) км")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .position(x: 10, y: y)
                }
            }
            .padding(.horizontal, 10)
        }
    }
}

struct EditFieldView: View {
    var title: String
    @Binding var text: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Form {
            TextField(title, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .navigationTitle("Редактировать \(title)")
        .navigationBarItems(trailing: Button("Сохранить") {
            presentationMode.wrappedValue.dismiss()
        })
    }
}

struct EditPasswordView: View {
    @Binding var password: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Form {
            SecureField("Пароль", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .navigationTitle("Редактировать пароль")
        .navigationBarItems(trailing: Button("Сохранить") {
            presentationMode.wrappedValue.dismiss()
        })
    }
}

struct EditGenderView: View {
    @Binding var gender: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Form {
            Picker("Пол", selection: $gender) {
                Text("Мужчина").tag("Мужчина")
                Text("Женщина").tag("Женщина")
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .navigationTitle("Редактировать пол")
        .navigationBarItems(trailing: Button("Сохранить") {
            presentationMode.wrappedValue.dismiss()
        })
    }
}

struct ProfileView: View {
    @AppStorage("currentUserId") var currentUserId: Int?
    @State private var username: String = "tit"
    @State private var nickname: String = "Tit"
    @State private var gender: String = "Мужчина"
    @State private var password: String = "********"
    @State private var isEditing: Bool = false

    var body: some View {
        NavigationView {
            VStack {
                Text("Профиль")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)

                if let userId = currentUserId {
                    Form {
                        Section {
                            // Логин
                            NavigationLink(destination: EditFieldView(title: "Логин", text: $username)) {
                                HStack {
                                    Text("Логин")
                                    Spacer()
                                    Text(username)
                                        .foregroundColor(.gray)
                                }
                            }

                            // Никнейм
                            NavigationLink(destination: EditFieldView(title: "Никнейм", text: $nickname)) {
                                HStack {
                                    Text("Никнейм")
                                    Spacer()
                                    Text(nickname)
                                        .foregroundColor(.gray)
                                }
                            }

                            // Пароль
                            NavigationLink(destination: EditPasswordView(password: $password)) {
                                HStack {
                                    Text("Пароль")
                                    Spacer()
                                    Text(password)
                                        .foregroundColor(.gray)
                                }
                            }

                            // Пол
                            NavigationLink(destination: EditGenderView(gender: $gender)) {
                                HStack {
                                    Text("Пол")
                                    Spacer()
                                    Text(gender)
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        Section(header: Text("THIS WEEK").font(.headline)) {
                            Text("График активности за неделю")
                                .foregroundColor(.gray)
                        }

                        Section {
                            Button(action: {
                                currentUserId = nil
                            }) {
                                Text("Выйти")
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            NavigationLink("", destination: HelloScreen().navigationBarBackButtonHidden(true))
                        }
                    }
                } else {
                    Text("Пользователь не авторизован")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Профиль")
        }
    }
}


// Кнопка выбора активности
struct ActivitySelectionButton: View {
    let imageName: String
    let title: String

    var body: some View {
        VStack {
            Image(imageName)
                .resizable()
                .frame(width: 50, height: 50)
            Text(title)
                .font(.headline)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}

struct HomePage_Previews: PreviewProvider {
    static var previews: some View {
        HomePage()
    }
}
