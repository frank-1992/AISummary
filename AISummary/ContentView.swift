//
//  ContentView.swift
//  AISummary
//
//  Created by 吴熠 on 2025/2/10.
//

import SwiftUI
import Foundation
import AppKit

//class ImagePreviewModel: ObservableObject {
//    @Published var previewImage: NSImage?
//    @Published var isPreviewing: Bool = false
//}

struct ContentView: View {
    @State private var workLogs: [WorkLog] = WorkLogStorage.load()
    @State private var isGeneratingReport = false
    @State private var isEditing = false
    @State private var editingIndex: Int = 0
    @State private var tempLog: WorkLog = WorkLog(date: Date(), content: "", imageData: [])
    
    var body: some View {
            VStack {
                List {
                    ForEach(workLogs.indices, id: \ .self) { index in
                        VStack(alignment: .leading) {
                            Text(workLogs[index].dateFormatted)
                                .font(.headline)
                            Text(workLogs[index].content)
                            
                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ForEach(workLogs[index].imageData.indices, id: \ .self) { imgIndex in
                                        if let image = NSImage(data: workLogs[index].imageData[imgIndex]) {
                                            Image(nsImage: image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 100)
                                                .onTapGesture {
                                                    showImagePreview(image: image)
                                                }
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                        .contentShape(Rectangle())
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
                    DispatchQueue.global(qos: .background).async {
                        workLogs[editingIndex] = tempLog
                        WorkLogStorage.save(workLogs)
                        DispatchQueue.main.async {
                            isEditing = false
                        }
                    }
                })
                .background(Color(NSColor.windowBackgroundColor))
                .frame(width: 400, height: 400)
            }
            .frame(minWidth: 400, minHeight: 300)
            .onDisappear {
                DispatchQueue.global(qos: .background).async {
                    WorkLogStorage.save(workLogs)
                }
            }
        }
    func addNewLog() {
        let newLog = WorkLog(date: Date(), content: "今天的工作内容", imageData: [])
        DispatchQueue.global(qos: .background).async {
            workLogs.append(newLog)
            WorkLogStorage.save(workLogs)
        }
    }
    
    func deleteLog(at offsets: IndexSet) {
        DispatchQueue.global(qos: .background).async {
            workLogs.remove(atOffsets: offsets)
            WorkLogStorage.save(workLogs)
        }
    }
    
    func startEditing(index: Int) {
        if index < workLogs.count {
            editingIndex = index
            tempLog = workLogs[index]
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

func showImagePreview(image: NSImage) {
    let previewWindow = ImagePreviewWindowController(image: image)
    previewWindow.showWindow(nil)
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
            
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(log.imageData.indices, id: \ .self) { imgIndex in
                        if let image = NSImage(data: log.imageData[imgIndex]) {
                            ZStack(alignment: .top) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                    .onTapGesture {
                                        showImagePreview(image: image)
                                    }
                                
                                Button(action: {
                                    log.imageData.remove(at: imgIndex)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            
            Button("添加图片") {
                selectImages()
            }
            
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
        .frame(width: 400, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    func selectImages() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image]
        openPanel.allowsMultipleSelection = true
        if openPanel.runModal() == .OK {
            let newImages = openPanel.urls.compactMap { NSImage(contentsOf: $0)?.tiffRepresentation }
            log.imageData.append(contentsOf: newImages)
        }
    }
}

struct ImagePreviewView: View {
    let image: NSImage
    
    var body: some View {
        VStack {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        }
        .frame(minWidth: 400, minHeight: 400) // 设置最小窗口大小
    }
}


class ImagePreviewWindowController: NSWindowController {
    init(image: NSImage) {
        let hostingView = NSHostingController(rootView: ImagePreviewView(image: image))
        
        let imageSize = image.size
        let windowWidth = min(imageSize.width, 800)
        let windowHeight = min(imageSize.height, 600)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingView
        if let mainWindow = NSApp.mainWindow {
            window.setFrameOrigin(NSPoint(x: mainWindow.frame.midX - window.frame.width / 2,
                                          y: mainWindow.frame.midY - window.frame.height / 2))
        }
        window.level = .normal
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}




struct WorkLog: Identifiable, Codable {
    let id = UUID()
    let date: Date
    var content: String
    var imageData: [Data]
    
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
