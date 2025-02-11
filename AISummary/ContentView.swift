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
    @State private var tempLog: WorkLog = WorkLog(date: Date(), content: "", imageData: [])
    
    var body: some View {
        ZStack {
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
                    Button(action: generateWeeklyReport) {
                        HStack {
                            if isGeneratingReport {
                                Text("生成中...")
                            } else {
                                Text("生成周报")
                            }
                        }
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
            
            // **全屏遮罩 + ProgressView**
            if isGeneratingReport {
                Color.black.opacity(0.4) // 半透明背景
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    ProgressView()
                        .scaleEffect(1.5) // 让加载动画稍大一点
                    Text("生成中...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .frame(width: 150, height: 100)
                .background(Color.gray.opacity(0.8))
                .cornerRadius(10)
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
            "\(dateFormatter.string(from: log.date)): \(log.content)"
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
        guard let url = URL(string: "http://localhost:11434/v1/chat/completions") else {
            completion("URL 无效")
            return
        }

        let cleanedInput = input.replacingOccurrences(of: "\n", with: " ")  // 移除换行，防止 JSON 解析错误

        // 构建系统提示词（控制输出格式）
        let systemPrompt = """
        你是一个专业的工作报告生成助手，请根据用户提供的工作日志内容，生成结构清晰、专业的 Markdown 格式周报。
        
        要求包含以下章节：
        # 程序开发工程师周报
        
        ## 本周工作内容
        - **[任务1]**: 详细描述任务内容和进展
        - **[任务2]**: 详细描述任务内容和进展
        - **[代码优化]**: 具体优化内容（如性能提升、Bug 修复等）
        
        ## 遇到的问题和解决方案
        - **问题 1**: 描述遇到的问题
          - **分析**: 可能的原因分析
          - **解决方案**: 采取的措施及最终结果
        - **问题 2**: 描述遇到的问题
          - **分析**: 可能的原因分析
          - **解决方案**: 采取的措施及最终结果
        
        ## OKR 进展
        | 目标 | 进度 | 备注 |
        |------|------|------|
        | **[目标 1]** | 50% | 已完成部分任务，剩余部分计划下周推进 |
        | **[目标 2]** | 80% | 进入优化阶段 |
        
        ## 下周工作计划
        - **[计划任务 1]**: 预计完成的任务及关键目标
        - **[计划任务 2]**: 预计完成的任务及关键目标
        - **[技术研究]**: 计划学习或攻克的技术难点
        
        ## 本周思考
        - [思考点 1]: 反思本周工作中遇到的问题或收获
        - [思考点 2]: 未来可能的优化方向或新思路
        
        注意：
        1. 使用中文撰写
        2. 根据日志内容合理归类到不同章节
        3. 适当优化表达，使其更具可读性
        4. 输出纯 Markdown 内容（不要包含额外说明）
        """

        
        let requestBody: [String: Any] = [
            "model": "deepseek-r1:8b",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": cleanedInput]
            ],
            "max_tokens": 5000
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url, timeoutInterval: 120)  // 增加超时时间
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion("请求失败: \(error.localizedDescription)")
                    }
                    return
                }

                guard let data = data else {
                    DispatchQueue.main.async {
                        completion("返回数据为空")
                    }
                    return
                }

                if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = jsonResponse["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    DispatchQueue.main.async {
                        let regexPattern = "\\s*<think>[\\s\\S]*?</think>\\s*"  // 确保删除前后可能存在的空白字符和换行
                        let filteredOutput = content.replacingOccurrences(of: regexPattern, with: "", options: [.regularExpression])
                            .trimmingCharacters(in: .whitespacesAndNewlines) // 移除头尾的空行
                        completion(filteredOutput)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion("解析 AI 响应失败")
                    }
                }
            }.resume()

        } catch {
            completion("JSON 序列化失败: \(error.localizedDescription)")
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
