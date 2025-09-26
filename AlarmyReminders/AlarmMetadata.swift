import AlarmKit

struct ReminderData: AlarmMetadata {
    let createdAt: Date
    let category: Category?
    
    init(category: Category? = nil) {
        self.createdAt = Date.now
        self.category = category
    }
    
    enum Category: String, Codable {
        case work
        case personal
        case health
        case social
        case other
        
        var icon: String {
            switch self {
            case .work: "briefcase"
            case .personal: "person"
            case .health: "heart"
            case .social: "person.2"
            case .other: "star"
            }
        }
    }
}
