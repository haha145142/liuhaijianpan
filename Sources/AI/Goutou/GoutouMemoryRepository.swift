// Sources/AI/Goutou/GoutouMemoryRepository.swift

import Foundation

public enum MemoryRepositoryError: Error, Equatable {
    case personNotFound
    case memoryNotFound
    case personMismatch
    case emptyContent
}

public enum GoutouMemoryRepository {

    public static func getMemories(
        personID: UUID,
        includeArchived: Bool = false,
        from defaults: UserDefaults = .standard
    ) -> [PersonMemory] {
        guard let profile = profile(id: personID, in: defaults) else { return [] }
        return includeArchived ? profile.memory : profile.memory.filter { !$0.archived }
    }

    public static func getMemory(id: UUID, personID: UUID, from defaults: UserDefaults = .standard) -> PersonMemory? {
        getMemories(personID: personID, includeArchived: true, from: defaults).first { $0.id == id }
    }

    @discardableResult
    public static func addMemory(
        content: String,
        personID: UUID,
        category: MemoryCategory = .stableFact,
        importance: Int = 3,
        confidence: Double = 1.0,
        sourceType: MemorySourceType = .manual,
        sourceSessionID: UUID? = nil,
        sourceMessageStart: Int? = nil,
        sourceMessageEnd: Int? = nil,
        from defaults: UserDefaults = .standard
    ) throws -> PersonMemory {
        let text = content.trimmed
        guard !text.isEmpty else { throw MemoryRepositoryError.emptyContent }
        guard profile(id: personID, in: defaults) != nil else { throw MemoryRepositoryError.personNotFound }

        let now = Date()
        let memory = PersonMemory(
            personID: personID,
            content: text,
            category: category,
            importance: GoutouMemoryApplier.clampImportance(importance),
            confidence: GoutouMemoryApplier.clampConfidence(confidence),
            createdAt: now,
            updatedAt: now,
            lastConfirmedAt: nil,
            sourceType: sourceType,
            sourceSessionID: sourceSessionID,
            sourceMessageStart: sourceMessageStart,
            sourceMessageEnd: sourceMessageEnd,
            archived: false
        )
        GoutouProfileStore.updateProfile(id: personID, in: defaults) { $0.memory.append(memory) }
        return memory
    }

    public static func updateMemory(
        id: UUID,
        personID: UUID,
        from defaults: UserDefaults = .standard,
        _ mutate: (inout PersonMemory) -> Void
    ) throws -> PersonMemory {
        guard var profile = profile(id: personID, in: defaults) else { throw MemoryRepositoryError.personNotFound }
        guard let index = profile.memory.firstIndex(where: { $0.id == id }) else {
            throw isKnownElsewhere(id: id, excluding: personID, in: defaults)
                ? MemoryRepositoryError.personMismatch
                : MemoryRepositoryError.memoryNotFound
        }

        var memory = profile.memory[index]
        mutate(&memory)
        memory.updatedAt = Date()
        if memory.content.trimmed.isEmpty { throw MemoryRepositoryError.emptyContent }

        profile.memory[index] = memory
        GoutouProfileStore.updateProfile(id: personID, in: defaults) { $0.memory = profile.memory }
        return memory
    }

    public static func updateMemory(
        _ memory: PersonMemory,
        forPerson personID: UUID,
        from defaults: UserDefaults = .standard
    ) throws -> PersonMemory {
        guard memory.personID == personID else { throw MemoryRepositoryError.personMismatch }
        return try updateMemory(id: memory.id, personID: personID, from: defaults) { stored in
            stored.content = memory.content
            stored.category = memory.category
            stored.importance = memory.importance
            stored.confidence = memory.confidence
            stored.archived = memory.archived
        }
    }

    public static func confirmMemory(
        id: UUID,
        personID: UUID,
        at date: Date = Date(),
        from defaults: UserDefaults = .standard
    ) throws -> PersonMemory {
        try updateMemory(id: id, personID: personID, from: defaults) { memory in
            memory.lastConfirmedAt = date
        }
    }

    public static func getStaleMemories(
        personID: UUID,
        includeArchived: Bool = false,
        at now: Date = Date(),
        config: MemoryDecayConfig = .default,
        from defaults: UserDefaults = .standard
    ) -> [PersonMemory] {
        guard let profile = profile(id: personID, in: defaults) else { return [] }
        return profile.memory
            .filter { includeArchived || !$0.archived }
            .filter { MemoryDecay.isStale($0, at: now, config: config) }
    }

    public static func refreshStaleState(
        personID: UUID,
        at now: Date = Date(),
        config: MemoryDecayConfig = .default,
        from defaults: UserDefaults = .standard
    ) -> Int {
        getStaleMemories(personID: personID, includeArchived: true, at: now, config: config, from: defaults).count
    }

    public static func archiveMemory(
        id: UUID,
        personID: UUID,
        archived: Bool = true,
        from defaults: UserDefaults = .standard
    ) throws {
        _ = try updateMemory(id: id, personID: personID, from: defaults) { memory in
            memory.archived = archived
        }
    }

    public static func deleteMemory(id: UUID, personID: UUID, from defaults: UserDefaults = .standard) throws {
        guard var profile = profile(id: personID, in: defaults) else { throw MemoryRepositoryError.personNotFound }
        guard profile.memory.contains(where: { $0.id == id }) else {
            throw isKnownElsewhere(id: id, excluding: personID, in: defaults)
                ? MemoryRepositoryError.personMismatch
                : MemoryRepositoryError.memoryNotFound
        }
        profile.memory.removeAll { $0.id == id }
        GoutouProfileStore.updateProfile(id: personID, in: defaults) { $0.memory = profile.memory }
    }

    public static func deleteAllMemories(personID: UUID, from defaults: UserDefaults = .standard) throws {
        guard profile(id: personID, in: defaults) != nil else { throw MemoryRepositoryError.personNotFound }
        GoutouProfileStore.updateProfile(id: personID, in: defaults) { $0.memory = [] }
    }

    public static func replaceMemories(_ memories: [PersonMemory], personID: UUID, from defaults: UserDefaults = .standard) throws {
        guard profile(id: personID, in: defaults) != nil else { throw MemoryRepositoryError.personNotFound }
        let owned = memories.filter { $0.personID == personID && !$0.content.trimmed.isEmpty }
        GoutouProfileStore.updateProfile(id: personID, in: defaults) { $0.memory = owned }
    }

    private static func profile(id: UUID, in defaults: UserDefaults) -> GoutouPersonProfile? {
        GoutouProfileStore.loadBook(from: defaults).profiles.first { $0.id == id }
    }

    private static func isKnownElsewhere(id: UUID, excluding personID: UUID, in defaults: UserDefaults) -> Bool {
        GoutouProfileStore.loadBook(from: defaults)
            .profiles
            .contains { $0.id != personID && $0.memory.contains { $0.id == id } }
    }
}
