//
//  ContentView.swift
//  AISummary
//
//  Created by 吴熠 on 2025/2/10.
//

// sk-1bdaa5d2390d40999b43fe88fd618275

import SwiftUI
import Foundation
import AppKit

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
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                deleteLog(at: IndexSet(integer: index))
                            }
                        }
                        .onTapGesture {
                            startEditing(index: index)
                        }
                    }
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

        let reportContent = workLogs.map { log in
            "- \(dateFormatter.string(from: log.date)): \(log.content)"
        }.joined(separator: "\n")

        generateReportWithAI(input: reportContent) { generatedText in
            DispatchQueue.main.async {
                saveReportToFile(generatedText)
                isGeneratingReport = false
            }
        }
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
    
    func generateReportWithAI(input: String, completion: @escaping (String) -> Void) {
        let apiKey = "sk-1bdaa5d2390d40999b43fe88fd618275" // 请替换为真实API密钥
        let endpoint = "https://api.deepseek.com/v1/chat/completions"
        
        // 构建系统提示词（控制输出格式）
        let systemPrompt = """
        你是一个专业的工作报告生成助手，请根据用户提供的工作日志内容，生成结构清晰、专业的Markdown格式报告。
        要求包含以下章节：
        # 本周工作概要
        ## 重点工作进展
        ## 任务完成情况
        ## 遇到的问题与解决方案
        ## 下周工作计划
        
        注意：
        1. 使用中文撰写
        2. 适当添加项目符号列表和分段
        3. 对技术细节保持专业表述
        4. 输出纯Markdown内容（不要包含额外说明）
        """
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ],
            "temperature": 0.3,  // 降低随机性保证稳定性
            "max_tokens": 2000    // 控制输出长度
        ]
        
        // 创建URLRequest
        guard let url = URL(string: endpoint),
              let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion("请求配置错误")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = httpBody
        
        // 发起网络请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 错误处理
            if let error = error {
                completion("请求失败: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion("服务器返回错误: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            
            guard let data = data else {
                completion("未收到有效响应")
                return
            }
            
            // 解析响应数据
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let choices = json?["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    DispatchQueue.main.async {
                        completion(content)
                    }
                } else {
                    completion("解析响应数据失败")
                }
            } catch {
                completion("数据解析错误: \(error.localizedDescription)")
            }
        }.resume()
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
