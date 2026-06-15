import Foundation
import SwiftData

@MainActor
struct GoalUseCase {
    let repository: DataRepositoryProtocol

    func save(_ goal: Goal, isNew: Bool, wasCompleted: Bool = false) throws {
        if isNew {
            repository.insert(goal)
        }
        if goal.isCompleted && !wasCompleted {
            try recordCompletionTransaction(for: goal)
        }
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }

    func delete(_ goal: Goal) throws {
        NotificationService.shared.cancelGoalReminder(goal: goal)
        repository.delete(goal)
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }

    func markComplete(_ goal: Goal) throws {
        let wasCompleted = goal.isCompleted
        goal.currentAmount = goal.targetAmount
        goal.isCompleted = true
        if !wasCompleted {
            try recordCompletionTransaction(for: goal)
        }
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }

    func contribute(_ goal: Goal, amount: Decimal) throws {
        let wasCompleted = goal.isCompleted
        goal.currentAmount = min(goal.targetAmount, goal.currentAmount + amount)
        if goal.currentAmount >= goal.targetAmount {
            goal.isCompleted = true
        }
        if goal.isCompleted && !wasCompleted {
            try recordCompletionTransaction(for: goal)
        }
        try repository.save()
        NotificationScheduler.syncAfterSave(context: repository.context)
    }

    private func recordCompletionTransaction(for goal: Goal) throws {
        guard let account = goal.linkedAccount else { return }

        let category = CategoryService.resolvedCategory(nil, for: TransactionType.income, context: repository.context)
        let transaction = Transaction(
            title: "Goal: \(goal.name)",
            amount: goal.targetAmount,
            type: .income,
            date: Date(),
            note: goal.note.isEmpty ? "Savings goal completed" : goal.note,
            account: account,
            category: category
        )
        repository.insert(transaction)
    }
}
