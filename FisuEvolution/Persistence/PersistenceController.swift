import CoreData
import Foundation

/// CoreData container for the save, isolated behind an actor so all access is
/// serialized and Swift 6 strict concurrency holds without `@unchecked` tricks.
///
/// Design decisions (see Docs/concurrency-conventions.md):
/// - The model is built programmatically — no `.xcdatamodeld`, no codegen classes,
///   so no non-Sendable `NSManagedObject` subclasses ever cross an isolation boundary.
/// - A single `SaveRecord` entity stores the canonical `PlayerState` as a JSON blob;
///   schema migrations are a pure Codable concern (`SaveMigrator`, F2), not CoreData's.
actor PersistenceController {
    private let container: NSPersistentContainer
    private var storeLoadError: Error?

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FisuEvolution", managedObjectModel: Self.makeModel())
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }
        // Synchronous by default (shouldAddStoreAsynchronously = false), so the
        // callback has run before init returns.
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        storeLoadError = loadError
    }

    /// Upserts the single save record. Throws only on real store failures; callers
    /// treat those as recoverable (the JSON snapshot is the backup).
    func save(payload: Data, schemaVersion: Int, updatedAt: Date) throws {
        if let storeLoadError { throw storeLoadError }
        let context = container.newBackgroundContext()
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            request.fetchLimit = 1
            let record = try context.fetch(request).first
                ?? NSEntityDescription.insertNewObject(forEntityName: Self.entityName, into: context)
            record.setValue(payload, forKey: "payload")
            record.setValue(Int64(schemaVersion), forKey: "schemaVersion")
            record.setValue(updatedAt, forKey: "updatedAt")
            try context.save()
        }
    }

    func loadLatest() throws -> (payload: Data, schemaVersion: Int)? {
        if let storeLoadError { throw storeLoadError }
        let context = container.newBackgroundContext()
        return try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            request.fetchLimit = 1
            guard let record = try context.fetch(request).first,
                  let payload = record.value(forKey: "payload") as? Data,
                  let schemaVersion = record.value(forKey: "schemaVersion") as? Int64
            else { return nil }
            return (payload, Int(schemaVersion))
        }
    }

    private static let entityName = "SaveRecord"

    private static func makeModel() -> NSManagedObjectModel {
        let payload = NSAttributeDescription()
        payload.name = "payload"
        payload.attributeType = .binaryDataAttributeType
        payload.isOptional = false

        let schemaVersion = NSAttributeDescription()
        schemaVersion.name = "schemaVersion"
        schemaVersion.attributeType = .integer64AttributeType
        schemaVersion.isOptional = false

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = false

        let entity = NSEntityDescription()
        entity.name = entityName
        entity.properties = [payload, schemaVersion, updatedAt]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }
}
