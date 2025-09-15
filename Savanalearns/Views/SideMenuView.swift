// Savanalearns/Views/SideMenuView.swift

import SwiftUI

struct SideMenuView: View {
    var onMenuItemTapped: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            Text("功能菜单")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "52616B"))
                .padding(.horizontal)
                .padding(.top, 60)
                .padding(.bottom, 20)
            
            Divider()
            
            // 使用 ScrollView 确保菜单内容可滚动
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DrawerText("学习计划") { onMenuItemTapped("学习计划") }
                    DrawerText("节目与练习") { onMenuItemTapped("节目与练习") }
                    DrawerText("精选阅读") { onMenuItemTapped("精选阅读") }
                    DrawerText("我的") { onMenuItemTapped("我的") }
                    DrawerText("社区") { onMenuItemTapped("社区") }
                    DrawerText("单词快闪 (测试)") { onMenuItemTapped("单词快闪") }
                    DrawerText("单词星图") { onMenuItemTapped("单词星图") }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "95E1D3"))
        .edgesIgnoringSafeArea(.all)
    }
}

struct DrawerText: View {
    let text: String
    let action: () -> Void
    
    init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .foregroundColor(Color(hex: "52616B"))
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// 建议将这个扩展放到一个单独的文件，比如 Utils/Color+Extension.swift
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: .whitespacesAndNewlines))
        _ = scanner.scanString("#")
        
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
