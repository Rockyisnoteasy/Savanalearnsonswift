// Views/LoginView.swift

import SwiftUI

struct LoginView: View {
    // 从外部接收 ViewModel
    @ObservedObject var viewModel: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoginMode = true

    var body: some View {
        VStack(spacing: 20) {
            Text(isLoginMode ? "登录" : "注册")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("邮箱", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            SecureField("密码", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // 如果 ViewModel 正在加载，就显示一个转圈的动画
            if viewModel.isLoading {
                ProgressView()
            }

            // 登录/注册按钮
            Button(isLoginMode ? "登录" : "注册") {
                // ✅ 关键修改在这里！
                // 我们现在调用 viewModel 里的方法，而不是 print
                if isLoginMode {
                    viewModel.login(email: email, password: password)
                } else {
                    viewModel.register(email: email, password: password)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(viewModel.isLoading) // 加载时禁用按钮


            // 切换模式的按钮
            Button(isLoginMode ? "没有帐号？去注册" : "已有帐号？去登录") {
                isLoginMode.toggle()
            }
        }
        .padding()
        // 当 errorMessage 出现时，显示一个弹窗
        .alert("提示", isPresented: .constant(viewModel.errorMessage != nil), actions: {
            Button("OK") { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
    }
}

#Preview {
    // 在预览中，我们需要提供一个临时的 AuthViewModel 实例
    LoginView(viewModel: AuthViewModel())
}
