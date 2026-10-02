# Class Diagram (Swift) — Family Organization App — MVP v1.3

> Source: documentation v1.4 — business rules up to RN64, use cases UC01–UC19 (2026-10-02). Domains kept separate per RNF14.

Legenda: «class» (azul), «struct» (verde), «enum» (amarelo), «protocol» (lilás), serviço (cinza). `+` público, `-` privado.

## Family, roles & access

### Family «class»

```swift
+ id: UUID
+ name: String
+ createdAt: Date
- creatorAppleUserID: String
+ members: [Member]
// ---
+ administrators: [Member] { get }
+ creator: Member { get }
+ addMember(_ m: Member, by admin: Member) throws
+ removeMember(_ id: UUID, by admin: Member) throws
+ carouselRange(today: Date) -> CarouselRange
```

### Member «class»

```swift
+ id: UUID
+ familyID: UUID
+ name: String
+ nickname: String?  // separate from name (RN63)
+ photoURL: URL?  // optional (RN63)
+ role: MemberRole
+ isFamilyCreator: Bool
+ isActive: Bool
+ removedAt: Date?
// ---
+ isAdministrator: Bool { get }
+ isAdult: Bool { get }
+ isKids: Bool { get }
+ displayName: String { get }  // nickname ?? name
+ editProfile(name: String, nickname: String?,
      photoURL: URL?, by editor: Member) throws
      // holder only, Kids included (RN63)
+ promote(by admin: Member) throws
+ demote(by admin: Member) throws
+ leaveAdministration() throws
+ setKidsMode(_ enabled: Bool, by admin: Member) throws
```

### MemberRole: String, Codable «enum»

```swift
case administrator
case member
case kids
```

### Invite «class»

```swift
+ id: UUID
+ familyID: UUID
+ memberID: UUID
- tokenHash: String
- passwordHash: String
+ createdBy: UUID
+ createdAt: Date
+ consumedAt: Date?
+ credentialsRotatedAt: Date?  // last resend
+ status: InviteStatus
// ---
+ static generate(for m: Member, by admin: Member) throws
      -> (invite: Invite, link: URL, password: String)
+ resend(by admin: Member) throws
      -> (link: URL, password: String)  // only if available
      // rotates tokenHash + passwordHash; same invite/member
      // previous link stops working; hashes only (RN46)
+ validate(token: String, password: String) throws
+ consume() throws -> Session
```

### InviteStatus: String, Codable «enum»

```swift
case available
case consumed
case invalidated
```

### Session «class»

```swift
+ id: UUID
+ memberID: UUID
+ familyID: UUID
- refreshTokenHash: String
+ createdAt: Date
+ revokedAt: Date?
// ---
+ isValid: Bool { get }
+ refresh(refreshToken: String) throws -> Session
+ revoke()
```

### AppleAuthenticating «protocol»

```swift
+ authenticate() async throws -> String  // appleUserID
```

### AccessService «class»

```swift
- apple: AppleAuthenticating
// ---
+ signInWithApple() async throws -> Family?
+ createFamily(name: String) async throws -> Family
+ generateInvite(for m: Member, by admin: Member) throws
+ resendInvite(_ id: UUID, by admin: Member) throws
      -> (link: URL, password: String)
+ join(token: String, password: String) async throws -> Session
+ revokeAccess(of memberID: UUID)
```

### AccessControl «struct»

```swift
+ static can(_ m: Member, _ action: Action) -> Bool
+ static require(_ m: Member, _ action: Action) throws
```

### Action «enum»

```swift
case manageMembers, generateInvite, resendInvite
case manageTasks, completeTask
case signalTask, validateSignal
case reopenTask
case manageMissions, manageRewardItems
case redeemReward
case viewLoad, accessFamilyArea
case generateWeeklyReport, shareWeeklyHighlight
case editOwnProfile
```

### DomainError: Error «enum»

```swift
case permissionDenied
case creatorProtected
case administratorInKidsMode
case titleRequired, invalidWeight
case completedTaskNotDeletable
case completedMissionProtected
case missionWithoutTasks
case invalidInvite, inviteConsumed
case sessionRevoked
case redemptionUnavailable
case staleState
case dateOutOfRange
case notProfileHolder, inviteNotResendable
```

## Tasks & routines

### FamilyTask «class»

```swift
+ id: UUID
+ familyID: UUID
+ routineID: UUID?
+ title: String
+ weight: EffortWeight
+ date: Date
+ assigneeIDs: Set<UUID>
+ status: TaskStatus
+ completions: [Completion]  // full history (UC17)
+ kidsSignal: KidsSignal?
// ---
+ isUnassigned: Bool { get }
+ currentCompletion: Completion? { get }  // undoneAt == nil
+ edit(title: String, weight: EffortWeight) throws
+ assign(_ ids: Set<UUID>, by: Member) throws
+ complete(by: Member, takeOver: Bool) throws -> Completion
+ signal(by kid: Member, photo: URL?) throws
+ confirmSignal(by admin: Member) throws -> Completion
+ rejectSignal(by admin: Member) throws
+ reopen(by admin: Member, missions: [Mission]) throws
      // undoes current completion; record kept (UC17)
+ canDelete(missions: [Mission]) -> Bool
```

### TaskStatus: String, Codable «enum»

```swift
case pending
case awaitingConfirmation
case completed
```

### EffortWeight: Int, Codable «enum»

```swift
case low = 1
case medium = 2
case high = 3
// ---
+ label: String { get }
```

### CompletionSource: String, Codable «enum»

```swift
case manual
case kidsConfirmation
```

### KidsSignal «struct»

```swift
+ id: UUID
+ signaledBy: UUID
+ signaledAt: Date
+ photoURL: URL?
+ decision: ValidationDecision?
+ decidedBy: UUID?
+ decidedAt: Date?
```

### ValidationDecision: String, Codable «enum»

```swift
case confirmed
case rejected
case closedByManualCompletion
```

### Completion «struct»

```swift
+ id: UUID
+ taskID: UUID
+ performedBy: UUID
+ creditedAssignees: Set<UUID>
+ creditedWeight: EffortWeight
+ completedAt: Date
+ scheduledDate: Date  // planned (RN61)
+ source: CompletionSource
+ confirmedBy: UUID?
+ undoneAt: Date?  // reopen; kept (UC17)
// ---
+ isValid: Bool { get }  // undoneAt == nil
```

### Routine «class»

```swift
+ id: UUID
+ familyID: UUID
+ title: String
+ weight: EffortWeight
+ assigneeIDs: Set<UUID>
+ frequency: RoutineFrequency
+ startDate: Date
+ isActive: Bool
// ---
+ upcomingDates(until: Date) -> [Date]
+ generateTasks(until: Date) -> [FamilyTask]
+ update(title: String?, weight: EffortWeight?,
      assignees: Set<UUID>?, from: Date) throws
+ end(from: Date)
```

### RoutineFrequency: Int, Codable «enum»

```swift
case daily = 1
case every7Days = 7
case every14Days = 14
case every21Days = 21
case every28Days = 28
// no monthly frequency
```

### ChangeScope «enum»

```swift
case thisOnly
case thisAndFuture
```

### TaskService «class»

```swift
+ create(title: String, weight: EffortWeight, assignees: Set<UUID>,
      frequency: RoutineFrequency?, by: Member) throws -> [FamilyTask]
+ edit(_ t: FamilyTask, scope: ChangeScope, by: Member) throws
+ delete(_ t: FamilyTask, scope: ChangeScope, by: Member) throws
+ complete(_ t: FamilyTask, takeOver: Bool, by: Member) throws
+ reopen(_ t: FamilyTask, by admin: Member) throws
+ kidsConfirmationQueue(by admin: Member) throws -> [FamilyTask]
```

## Family area, progress & load (Day / Week)

### FamilyArea «class»

```swift
+ user: Member
+ selectedDate: Date
+ period: ViewPeriod  // day | week (RN61)
+ selectedMemberID: UUID?  // nil = whole family
+ range: CarouselRange
// ---
+ select(date: Date) throws
+ select(period: ViewPeriod)
+ select(memberID: UUID?)
+ interval: DateInterval { get }  // day or Mon–Sun
+ progress() -> PeriodProgress  // family or member
+ tasks() -> [FamilyTask]  // by period & member
+ load() throws -> PeriodLoad
+ weeklyReportPDF() async throws -> URL  // UC18
+ canManageMembers: Bool { get }
+ canValidateKids: Bool { get }
  // date, period & member kept on return (RN60)
```

### CarouselRange «struct»

```swift
+ start: Date  // family creation date
+ end: Date    // last day of current month
// ---
+ init(familyCreatedAt: Date, today: Date, calendar: Calendar)
+ contains(_ date: Date) -> Bool
```

### ViewPeriod: String, Codable «enum»

```swift
case day
case week
```

### PeriodProgress «struct»

```swift
+ interval: DateInterval
+ period: ViewPeriod
+ memberID: UUID?  // nil = family
+ completed: Int
+ total: Int
// ---
+ percentage: Double? { get }  // nil = "No tasks"
+ static personal(of m: Member, tasks: [FamilyTask],
      in interval: DateInterval) -> Self
+ static family(tasks: [FamilyTask], in interval: DateInterval) -> Self
  // tasks counted by scheduled date (FamilyTask.date)
```

### PeriodLoad «struct»

```swift
+ interval: DateInterval  // day or Mon–Sun
+ period: ViewPeriod
+ loadByMember: [UUID: Int]
+ completedCountByMember: [UUID: Int]
// ---
+ total: Int { get }
+ share(of id: UUID) -> Double?
+ completedCount(of id: UUID) -> Int
```

### PeriodCalculator «struct»

```swift
+ calendar: Calendar
// ---
+ interval(_ p: ViewPeriod, containing date: Date) -> DateInterval
+ load(_ p: ViewPeriod, containing date: Date,
      completions: [Completion]) -> PeriodLoad
  // valid completions by completedAt (RN61)
```

## Missions & rewards

### Mission «class»

```swift
+ id: UUID
+ familyID: UUID
+ title: String
+ details: String?
+ createdBy: UUID
+ taskIDs: [UUID]
+ badge: Badge?
+ status: MissionStatus
+ completedAt: Date?
+ reward: RedeemedReward?
// ---
+ isRedemptionAvailable: Bool { get }
+ progress(tasks: [FamilyTask]) -> Double
+ edit(title: String, details: String?, badge: Badge?) throws
+ link(_ t: FamilyTask, by admin: Member) throws
+ unlink(_ id: UUID, replacement: FamilyTask?) throws
+ updateStatus(tasks: [FamilyTask])
+ recordReward(_ r: RedeemedReward) throws
+ awardBadge(to m: Member, existing: [BadgeAward])
      -> BadgeAward?  // nil if already awarded (RN64)
```

### MissionStatus: String, Codable «enum»

```swift
case inProgress
case completed
```

### Badge «struct»

```swift
+ id: UUID
+ name: String
+ icon: String  // SF Symbol
```

### BadgeAward «struct»

```swift
+ id: UUID
+ memberID: UUID
+ missionID: UUID
+ badgeID: UUID
+ awardedAt: Date
// ---
  // unique (memberID, missionID)
  // independent of redemption (RN64)
```

### RewardWheel «class»

```swift
+ mission: Mission
+ items: [RewardItem]
+ currentResult: RewardItem?
// ---
+ init(mission: Mission, items: [RewardItem]) throws
+ spin() -> RewardItem
+ rejectResult()
+ accept(by admin: Member) throws -> RedeemedReward
```

### RedeemedReward «struct»

```swift
+ itemID: UUID
+ title: String
+ acceptedBy: UUID
+ acceptedAt: Date
```

### RewardItem «class»

```swift
+ id: UUID
+ familyID: UUID?  // nil = predefined
+ title: String
+ details: String?
+ source: RewardItemSource
+ createdBy: UUID?
// ---
+ static predefined: [RewardItem]
+ static custom(title: String, by admin: Member) throws -> Self
```

### RewardItemSource: String, Codable «enum»

```swift
case predefined
case custom
```

## Weekly report (PDF)

### WeeklyReport «struct»

```swift
+ id: UUID
+ familyID: UUID
+ familyName: String
+ week: DateInterval  // Monday to Sunday
+ generatedAt: Date
+ generatedBy: UUID
+ load: PeriodLoad
+ familyProgress: PeriodProgress
+ members: [MemberReportLine]
```

### WeeklyReportService «class»

```swift
- calculator: PeriodCalculator
- renderer: PDFRendering
// ---
+ build(weekOf date: Date, family: Family, tasks: [FamilyTask],
      completions: [Completion], by m: Member) throws -> WeeklyReport
  // from FamilyArea; Kids have no access (RN33)
+ exportPDF(_ r: WeeklyReport) throws -> URL  // UC18
```

### MemberReportLine «struct»

```swift
+ memberID: UUID
+ displayName: String
+ load: Int
+ loadShare: Double?
+ progress: PeriodProgress
+ completedCount: Int
```

### PDFRendering «protocol»

```swift
+ render(_ r: WeeklyReport) throws -> Data
```

## Weekly highlight

### WeeklyHighlight «class»

```swift
+ id: UUID
+ familyID: UUID
+ week: DateInterval
+ winnerIDs: Set<UUID>  // > 1 on tie
+ winningLoad: Int
+ computedAt: Date
+ notifiedAt: Date?
// ---
+ isTie: Bool { get }
+ shareText(names: [UUID: String]) -> String
  // unique (familyID, week): computed once
```

### WeeklyHighlightService «class»

```swift
- notifier: HighlightNotifying
// ---
+ computeIfNeeded(family: Family, load: PeriodLoad,
      existing: WeeklyHighlight?) throws -> WeeklyHighlight?
      // nil if no load or already computed
+ notifyOnce(_ h: WeeklyHighlight, members: [Member]) async throws
+ share(_ h: WeeklyHighlight, by m: Member) -> String  // optional
```

### HighlightNotifying «protocol»

```swift
+ notify(_ h: WeeklyHighlight, to: [Member]) async throws
```

## Relacionamentos

| Origem | Relação | Destino | Rótulo | Multiplicidade (origem → destino) |
|---|---|---|---|---|
| Family | composição ◆ | Member | members | 1 → 1..* |
| Member | associação → | MemberRole | role | – → 1 |
| Invite | associação → | Member | for | 0..* → 1 |
| Invite | associação → | InviteStatus | status | – → 1 |
| Session | associação → | Member | of | 0..* → 1 |
| AccessService | dependência ⇢ | AppleAuthenticating | «use» | – → – |
| AccessService | dependência ⇢ | Invite | «create» | – → – |
| AccessService | dependência ⇢ | AccessControl | «use» | – → – |
| AccessControl | dependência ⇢ | Action | «use» | – → – |
| Family | composição ◆ | FamilyTask | tasks | 1 → 0..* |
| FamilyTask | associação → | Member | assignees | 0..* → 0..* |
| FamilyTask | associação → | TaskStatus | status | – → 1 |
| FamilyTask | composição ◆ | Completion | completions | 1 → 0..* |
| FamilyTask | composição ◆ | KidsSignal | kidsSignal | 1 → 0..1 |
| Completion | associação → | CompletionSource | source | – → 1 |
| KidsSignal | associação → | ValidationDecision | decision | – → 0..1 |
| Routine | associação → | FamilyTask | generates | 0..1 → 0..* |
| Routine | associação → | RoutineFrequency | frequency | – → 1 |
| TaskService | dependência ⇢ | ChangeScope | «use» | – → – |
| FamilyArea | associação → | CarouselRange | range | – → 1 |
| FamilyArea | dependência ⇢ | PeriodProgress | «create» | – → – |
| FamilyArea | dependência ⇢ | PeriodCalculator | «use» | – → – |
| PeriodCalculator | dependência ⇢ | PeriodLoad | «create» | – → – |
| Mission | agregação ◇ | FamilyTask | links | 0..* → 1..* |
| Mission | associação → | MissionStatus | status | – → 1 |
| Mission | composição ◆ | RedeemedReward | reward | 1 → 0..1 |
| Mission | composição ◆ | Badge | badge | 1 → 0..1 |
| RewardWheel | associação → | Mission | mission | – → 1 |
| RewardWheel | associação → | RewardItem | items | – → 1..* |
| RewardWheel | dependência ⇢ | RedeemedReward | «create» | – → – |
| RedeemedReward | associação → | RewardItem | item | – → 1 |
| RewardItem | associação → | RewardItemSource | source | – → 1 |
| FamilyArea | associação → | ViewPeriod | period | – → 1 |
| Mission | composição ◆ | BadgeAward | awards | 1 → 0..* |
| BadgeAward | associação → | Badge | badge | – → 1 |
| WeeklyReport | composição ◆ | MemberReportLine | members | 1 → 1..* |
| WeeklyReportService | dependência ⇢ | WeeklyReport | «create» | – → – |
| WeeklyReportService | dependência ⇢ | PDFRendering | «use» | – → – |
| WeeklyReportService | dependência ⇢ | PeriodCalculator | «use» | – → – |
| FamilyArea | dependência ⇢ | WeeklyReportService | «use» | – → – |
| WeeklyHighlightService | dependência ⇢ | WeeklyHighlight | «create» | – → – |
| WeeklyHighlightService | dependência ⇢ | HighlightNotifying | «use» | – → – |

## Regras de domínio refletidas

### Domain rules reflected

- A task has a single status shared by all assignees; no partial completion (RN55).
- Completion credits the full weight to each final assignee; whoever performs it may get no credit (RN30, RN56).
- Take over replaces all assignees; unassigned → completer becomes assignee (RN48).
- Kids signal: pending → awaitingConfirmation; photo optional (RN23, RN54).
- First valid decision wins; manual completion closes validation (RN24).
- Completion history kept: reopen sets undoneAt on the current one; a new Completion is appended on re-completion (UC17).

### Load, progress & Family area

- Day or Week (Monday to Sunday) for both progress and load (RN61).
- Progress counts tasks by scheduled date; load counts valid completions by completion date (RN61).
- Total load = sum of individual loads; no division by zero (RN28, RN31).
- Progress (personal and family) = completed / total; each task counts once; "No tasks" when total = 0 (RN60).
- Carousel: family creation → last day of current month (RN49).
- Family area: Day/Week, per-member view, context preserved; Kids cannot access it (RN33, RN60).

### Missions, rewards & access

- Missions have no deadline, ≥ 1 individually linked task (RN36, RN50, RN51).
- A completed mission is immutable; only the single redemption records the reward (RN53, RN58).
- Reopen: admin only, task linked to an in-progress mission and to no completed one; sets Completion.undoneAt (RN57).
- Invite: single-use link + password; tokens and passwords stored only as hashes (RN46, RNF17).
- Session via non-expiring refresh token, revoked on removal (RN47, RNF22).
- Invite resend (status available only): rotates token and password on the same invite; the previous link stops working.
- Profile: optional photo and nickname, edited only by the holder, Kids included (RN63).
- Badges: one BadgeAward per member and mission, independent of redemption (RN64).

### Weekly report & highlight

- PDF report: family, week, generation time, load, progress and completed count per member; generated from the Family area (UC18).
- Weekly highlight: one result per family and week (no duplicates); ties produce several winners (UC19).
- Notification sent once (notifiedAt); sharing is optional (UC19).

