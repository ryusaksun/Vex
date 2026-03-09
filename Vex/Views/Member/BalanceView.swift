import SwiftUI

struct BalanceView: View {
    @Environment(AuthManager.self) private var auth

    @State private var records: [BalanceRecord] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var error: String?

    private let client = V2EXClient.shared

    var body: some View {
        List {
            // Balance header
            if let balance = auth.balance {
                Section {
                    HStack(spacing: 24) {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.yellow)
                            Text("\(balance.gold)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.gray)
                            Text("\(balance.silver)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.brown)
                            Text("\(balance.bronze)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }

            // Transaction records
            Section("交易记录") {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(record.type)
                                .font(.subheadline)
                            Spacer()
                            Text(record.amount.hasPrefix("-") ? record.amount : "+\(record.amount)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(record.amount.hasPrefix("-") ? .red : .green)
                        }

                        Text(record.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack {
                            Text(record.time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text("余额: \(record.balance)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if currentPage < totalPages {
                    Button("加载更多") {
                        Task { await loadMore() }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .navigationTitle("账户余额")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadRecords(page: 1)
        }
        .overlay {
            if isLoading && records.isEmpty {
                LottieLoadingView()
            } else if let error, records.isEmpty {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
        }
        .task {
            await loadRecords(page: 1)
        }
    }

    private func loadRecords(page: Int) async {
        isLoading = true
        if page == 1 {
            error = nil
        }
        do {
            let response = try await client.getBalanceRecords(page: page)
            if page == 1 {
                records = response.data
            } else {
                records.append(contentsOf: response.data)
            }
            currentPage = response.pagination.current
            totalPages = response.pagination.total
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading, currentPage < totalPages else { return }
        await loadRecords(page: currentPage + 1)
    }
}
