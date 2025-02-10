//
//  ContentView.swift
//  AISummary
//
//  Created by 吴熠 on 2025/2/10.
//

import SwiftUI
import Foundation
import AppKit

struct ContentView: View {
    @State private var workLogs: [WorkLog] = WorkLogStorage.load()
    @State private var isGeneratingReport = false
    @State private var isEditing = false
    @State private var editingIndex: Int = 0
    @State private var tempLog: WorkLog = WorkLog(date: Date(), content: "")
    
    var body: some View {
        VStack {
            List {
                ForEach(workLogs.indices, id: \ .self) { index in
                    VStack(alignment: .leading) {
                        Text(workLogs[index].dateFormatted)
                            .font(.headline)
                        Text(workLogs[index].content)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading) // 让整个行的热区变大
                    .contentShape(Rectangle()) // 让空白区域也可点击
                    .onTapGesture {
                        startEditing(index: index)
                    }
                }
                .onDelete(perform: deleteLog)
            }
            
            HStack {
                Button("添加记录") {
                    addNewLog()
                }
                
                Button("生成周报") {
                    generateWeeklyReport()
                }
                .disabled(isGeneratingReport)
            }
            .padding()
        }
        .sheet(isPresented: $isEditing) {
            EditView(log: $tempLog, isEditing: $isEditing, onSave: {
                workLogs[editingIndex] = tempLog
                WorkLogStorage.save(workLogs)
            })
            .background(Color(NSColor.windowBackgroundColor))
            .frame(width: 400, height: 300)
        }
        .frame(minWidth: 400, minHeight: 300)
        .onDisappear {
            WorkLogStorage.save(workLogs)
        }
    }
    
    func addNewLog() {
        let newLog = WorkLog(date: Date(), content: "今天的工作内容")
        workLogs.append(newLog)
        WorkLogStorage.save(workLogs)
    }
    
    func deleteLog(at offsets: IndexSet) {
        workLogs.remove(atOffsets: offsets)
        WorkLogStorage.save(workLogs)
    }
    
    func startEditing(index: Int) {
        if index < workLogs.count {
            editingIndex = index
            tempLog = workLogs[index] // 使用临时对象
            isEditing = true
        }
    }
    
    func generateWeeklyReport() {
        isGeneratingReport = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let markdownReport = workLogs.map { log in
            "- \(dateFormatter.string(from: log.date)): \(log.content)"
        }.joined(separator: "\n")
        
        saveReportToFile(markdownReport)
        
        isGeneratingReport = false
    }
    
    func saveReportToFile(_ report: String) {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("weekly_report.md")
        do {
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } catch {
            print("Error saving report: \(error)")
        }
    }
}

struct EditView: View {
    @Binding var log: WorkLog
    @Binding var isEditing: Bool
    var onSave: () -> Void
    
    var body: some View {
        VStack {
            TextEditor(text: $log.content)
                .frame(minHeight: 100)
                .padding()
                .border(Color.black, width: 1)
                .background(Color(NSColor.textBackgroundColor))
            
            HStack {
                Button("保存") {
                    onSave()
                    isEditing = false
                }
                Button("取消") {
                    isEditing = false
                }
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct WorkLog: Identifiable, Codable {
    let id = UUID()
    let date: Date
    var content: String = "wahahhahah"
    
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

class WorkLogStorage {
    static let fileURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("worklogs.json")
    }()
    
    static func save(_ logs: [WorkLog]) {
        do {
            let data = try JSONEncoder().encode(logs)
            try data.write(to: fileURL)
        } catch {
            print("Error saving logs: \(error)")
        }
    }
    
    static func load() -> [WorkLog] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([WorkLog].self, from: data)
        } catch {
            return []
        }
    }
}


#Preview {
    ContentView()
}
