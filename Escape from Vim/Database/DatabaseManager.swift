import Foundation
import SQLite
import CryptoKit
import CoreLocation

private func hashPassword(_ password: String) -> String {
    let hashed = SHA256.hash(data: Data(password.utf8))
    return hashed.map { String(format: "%02hhx", $0) }.joined()
}

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection?

    // Таблицы и их колонки
    private let users = Table("users")
    private let activities = Table("activities")
    private let routes = Table("routes")

    // Колонки для users
    private let id = SQLite.Expression<Int64>("id")
    private let username = SQLite.Expression<String>("username")
    private let nickname = SQLite.Expression<String>("nickname")
    private let password = SQLite.Expression<String>("password")
    private let gender = SQLite.Expression<String>("gender")

    // Колонки для activities
    private let activityId = SQLite.Expression<Int64>("id")
    private let type = SQLite.Expression<String>("type")
    private let distance = SQLite.Expression<Double>("distance")
    private let duration = SQLite.Expression<String>("duration")
    private let date = SQLite.Expression<Date>("date")
    private let userId = SQLite.Expression<Int64>("userId")

    // Колонки для routes
    private let routeId = SQLite.Expression<Int64>("routeId")
    private let activityRefId = SQLite.Expression<Int64>("activityId")
    private let latitude = SQLite.Expression<Double>("latitude")
    private let longitude = SQLite.Expression<Double>("longitude")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        print("Database path: \(path)")
        do {
            db = try Connection("\(path)/db.sqlite3")
            createUsersTable()
            createActivityAndRouteTables()
        } catch {
            print("Ошибка подключения к базе данных: \(error)")
        }
    }

    private func createUsersTable() {
        do {
            try db?.run(users.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(username, unique: true)
                table.column(nickname)
                table.column(password)
                table.column(gender)
            })
        } catch {
            print("Ошибка создания таблицы пользователей: \(error)")
        }
    }

    private func createActivityAndRouteTables() {
        do {
            // Создаем таблицу activities, если она не существует
            try db?.run(activities.create(ifNotExists: true) { table in
                table.column(activityId, primaryKey: .autoincrement)
                table.column(type)
                table.column(distance)
                table.column(duration)
                table.column(date)
                table.column(SQLite.Expression<String>("comment"))
                table.column(userId)
            })

            // Создаем таблицу routes, если она не существует
            try db?.run(routes.create(ifNotExists: true) { table in
                table.column(routeId, primaryKey: .autoincrement)
                table.column(activityRefId)
                table.column(latitude)
                table.column(longitude)
                table.column(SQLite.Expression<Int>("segmentIndex"))
                table.foreignKey(activityRefId, references: activities, activityId)
            })

            // Проверяем, существует ли колонка comment, и добавляем ее, если нет
            let commentExists = try db?.scalar(
                "SELECT COUNT(*) FROM pragma_table_info('activities') WHERE name = 'comment'"
            ) as? Int64 == 1

            if !commentExists {
                try db?.run("ALTER TABLE activities ADD COLUMN comment TEXT")
            }

            // Проверяем, существует ли колонка userId, и добавляем ее, если нет
            let userIdExists = try db?.scalar(
                "SELECT COUNT(*) FROM pragma_table_info('activities') WHERE name = 'userId'"
            ) as? Int64 == 1

            if !userIdExists {
                try db?.run("ALTER TABLE activities ADD COLUMN userId INTEGER")
            }
        } catch {
            print("Ошибка создания таблиц активностей и маршрутов: \(error)")
        }
    }

    func registerUser(username: String, nickname: String, password: String, gender: String) -> Bool {
        guard let db = db else {
            print("База данных не инициализирована")
            return false
        }

        do {
            let hashedPassword = hashPassword(password)
            try db.run(users.insert(
                self.username <- username,
                self.nickname <- nickname,
                self.password <- hashedPassword,
                self.gender <- gender
            ))
            print("Пользователь зарегистрирован: \(username)")
            return true
        } catch let error as SQLite.Result {
            print("Ошибка SQLite: \(error)")
            return false
        } catch {
            print("Неизвестная ошибка: \(error)")
            return false
        }
    }

    func loginUser(username: String, password: String) -> Int64? {
        do {
            let hashedPassword = hashPassword(password)
            if let user = try db?.pluck(users.filter(self.username == username && self.password == hashedPassword)) {
                print("Успешный вход. Пользователь: \(user[self.nickname])")
                return user[id] // Возвращаем userId
            }
        } catch {
            print("Ошибка авторизации: \(error)")
        }
        return nil
    }

    func saveActivity(activity: Activity, userId: Int64) {
        guard let db = db else { return }
        do {
            // Сохраняем активность
            let activityId = try db.run(activities.insert(
                type <- activity.type,
                distance <- activity.distance,
                duration <- activity.duration,
                date <- activity.date,
                SQLite.Expression<String>("comment") <- activity.comment,
                self.userId <- userId 
            ))

            // Сохраняем маршрут
            for (segmentIndex, segment) in activity.routes.enumerated() {
                for point in segment {
                    try db.run(routes.insert(
                        activityRefId <- activityId,
                        latitude <- point.latitude,
                        longitude <- point.longitude,
                        SQLite.Expression<Int>("segmentIndex") <- segmentIndex
                    ))
                }
            }
            print("Активность успешно сохранена: \(activity.type)")
        } catch {
            print("Ошибка сохранения активности: \(error)")
        }
    }

    func updateActivity(activity: Activity) {
        guard let db = db else { return }
        do {
            // Находим активность по ID
            let activityToUpdate = activities.filter(activityId == activity.id)

            // Обновляем активность
            try db.run(activityToUpdate.update(
                type <- activity.type,
                distance <- activity.distance,
                duration <- activity.duration,
                date <- activity.date,
                SQLite.Expression<String>("comment") <- activity.comment
            ))

            print("Активность успешно обновлена: \(activity.type)")
        } catch {
            print("Ошибка обновления активности: \(error)")
        }
    }

    func loadActivities(for userId: Int64) -> [Activity] {
        guard let db = db else { return [] }
        var loadedActivities: [Activity] = []
        do {
            let query = activities.filter(self.userId == userId)
            for activityRow in try db.prepare(query) {
                let id = activityRow[activityId]

                // Загружаем маршрут
                let routePoints = try db.prepare(routes.filter(activityRefId == id))
                var segments: [[CLLocationCoordinate2D]] = []
                var currentSegment: [CLLocationCoordinate2D] = []
                var lastSegmentIndex: Int? = nil

                for routeRow in routePoints {
                    let segmentIndex = routeRow[SQLite.Expression<Int>("segmentIndex")]
                    let point = CLLocationCoordinate2D(latitude: routeRow[latitude], longitude: routeRow[longitude])

                    if segmentIndex != lastSegmentIndex {
                        if !currentSegment.isEmpty {
                            segments.append(currentSegment)
                            currentSegment = []
                        }
                        lastSegmentIndex = segmentIndex
                    }
                    currentSegment.append(point)
                }

                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }

                // Создаем активность
                let activity = Activity(
                    id: id,
                    type: activityRow[type],
                    distance: activityRow[distance],
                    duration: activityRow[duration],
                    date: activityRow[date],
                    routes: segments,
                    comment: activityRow[SQLite.Expression<String>("comment")]
                )
                loadedActivities.append(activity)
            }
        } catch {
            print("Ошибка загрузки активностей: \(error)")
        }
        return loadedActivities
    }
    
    func updateUser(userId: Int64, username: String?, nickname: String?, password: String?, gender: String?) -> Bool {
            guard let db = db else { return false }
            do {
                let userToUpdate = users.filter(id == userId)
                var setters: [SQLite.Setter] = []

                if let username = username {
                    setters.append(self.username <- username)
                }
                if let nickname = nickname {
                    setters.append(self.nickname <- nickname)
                }
                if let password = password {
                    setters.append(self.password <- hashPassword(password))
                }
                if let gender = gender {
                    setters.append(self.gender <- gender)
                }

                if !setters.isEmpty {
                    try db.run(userToUpdate.update(setters))
                    print("Данные пользователя успешно обновлены")
                    return true
                }
            } catch {
                print("Ошибка обновления данных пользователя: \(error)")
            }
            return false
        }


    // Метод для получения пользователя по ID
    func getUserById(_ userId: Int64) -> User? {
        guard let db = db else { return nil }
        do {
            if let user = try db.pluck(users.filter(id == userId)) {
                return User(
                    id: user[id],
                    username: user[username],
                    nickname: user[nickname],
                    gender: user[gender]
                )
            }
        } catch {
            print("Ошибка загрузки данных пользователя: \(error)")
        }
        return nil
    }

    // Структура для хранения данных пользователя
    struct User {
        let id: Int64
        let username: String
        let nickname: String
        let gender: String
    }
}
