// Savanalearns/Views/DictionarySearchBarView.swift

import SwiftUI

struct DictionarySearchBarView: View {
    // 从环境中获取我们之前创建的 ViewModel
    @EnvironmentObject var viewModel: DictionaryViewModel
    
    // 控制底部弹出工作表 (Bottom Sheet) 的状态
    @State private var showDefinitionSheet = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                TextField("右滑打开功能菜单...", text: $viewModel.searchInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                // 查字典按钮
                Button(action: {
                    // 点击按钮时，获取释义并准备弹出
                    viewModel.searchResultDefinition = viewModel.getDefinition(for: viewModel.searchInput)
                    viewModel.suggestions = [] // 清空建议
                    hideKeyboard()
                    showDefinitionSheet = true
                }) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
            }
            
            // 搜索建议列表
            if !viewModel.suggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.suggestions, id: \.word) { suggestion in
                            VStack(alignment: .leading) {
                                Text(suggestion.word).font(.headline)
                                Text(suggestion.definition)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle()) // 使整个区域可点击
                            .onTapGesture {
                                viewModel.searchInput = suggestion.word
                                viewModel.searchResultDefinition = viewModel.getDefinition(for: suggestion.word)
                                viewModel.suggestions = [] // 点击后清空建议
                                hideKeyboard()
                                showDefinitionSheet = true
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300) // 限制建议列表的最大高度
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .shadow(radius: 3)
                .transition(.opacity)
            }
        }
        // 使用 .sheet 来实现底部弹窗效果
        .sheet(isPresented: $showDefinitionSheet) {
            DefinitionSheetView(
                word: viewModel.searchInput,
                definition: viewModel.searchResultDefinition
            )
        }
    }
    
    // 隐藏键盘的辅助函数
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// 底部弹出的释义视图
struct DefinitionSheetView: View {
    let word: String
    let definition: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(word)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(definition ?? "正在加载释义...")
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("单词释义")
            .navigationBarItems(trailing: Button("完成") {
                dismiss()
            })
        }
    }
}
