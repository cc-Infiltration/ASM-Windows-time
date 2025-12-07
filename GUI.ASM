; 动态时间显示程序
; 使用32位汇编语言编写的Windows GUI应用程序

.386                   ; 使用386处理器指令集
.Model Flat, StdCall   ; 平坦内存模型，标准调用约定
Option Casemap :None   ; 区分大小写

; 包含必要的Windows头文件
Include windows.inc    ; Windows核心API定义
Include user32.inc     ; 用户界面相关API
Include kernel32.inc   ; 内核相关API
Include gdi32.inc      ; 图形设备接口相关API

; 链接必要的Windows库文件
includelib gdi32.lib   ; 图形设备接口库
IncludeLib user32.lib  ; 用户界面临时库
IncludeLib kernel32.lib; 内核临时库

; 函数声明
WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD  ; 应用程序入口函数
WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD   ; 窗口过程函数
	
.DATA                   ; 已初始化数据段
	szClassName db "亿染工作室",0           ; 窗口类名
	szWindowTitle db "动态时间",0           ; 窗口标题
	szClassNameStatic db "STATIC",0         ; 静态文本控件类名
	IDC_TIME_STATIC equ 1001                 ; 时间显示控件ID
	szTimeFormat db "当前时间: %02d:%02d:%02d",0  ; 时间格式化字符串
	szTimeLabel db "当前时间: 00:00:00",0    ; 初始显示时间

.DATA?                  ; 未初始化数据段
	hInstance	dd ?         ; 应用程序实例句柄
	hTimeStatic	dd ?       ; 时间显示控件句柄
	szTimeBuffer db 32 dup(?)  ; 时间缓冲区，用于存储格式化后的时间字符串
	timerID	dd ?           ; 定时器ID
	
.CODE                   ; 代码段
START:                  ; 程序入口点

	; 获取当前应用程序实例句柄
	invoke GetModuleHandle,NULL
	mov hInstance,eax
	
	; 调用应用程序主函数
	invoke WinMain,hInstance,NULL,NULL,SW_SHOWDEFAULT
	
	; 退出程序
	invoke ExitProcess,0

; 应用程序主函数
; 参数:
; hInst: 应用程序实例句柄
; hPrevInst: 前一个实例句柄（Win32中始终为NULL）
; CmdLine: 命令行参数
; CmdShow: 窗口显示方式
WinMain proc hInst:DWORD,hPrevInst:DWORD,CmdLine:DWORD,CmdShow:DWORD
	LOCAL wc   :WNDCLASSEX  ; 窗口类结构体
	LOCAL msg  :MSG          ; 消息结构体
	local hWnd :HWND         ; 窗口句柄
	
	; 初始化窗口类结构体
	mov wc.cbSize,sizeof WNDCLASSEX  ; 设置结构体大小
	mov wc.style,CS_HREDRAW or CS_VREDRAW or CS_BYTEALIGNWINDOW  ; 窗口样式
	mov wc.lpfnWndProc,offset WndProc  ; 设置窗口过程函数
	mov wc.cbClsExtra,NULL  ; 类额外数据
	mov wc.cbWndExtra,NULL  ; 窗口额外数据
	push hInst
	pop wc.hInstance ; 设置实例句柄
	mov wc.hbrBackground,COLOR_BTNFACE+1  ;设置背景色
	mov wc.lpszMenuName,NULL  ;无菜单
	mov wc.lpszClassName,offset szClassName  ;设置类名
	invoke LoadIcon,hInst,100 ;加载图标
	mov wc.hIcon,eax
	invoke LoadCursor,NULL,IDC_ARROW  ;加载光标
	mov wc.hCursor,eax
	mov wc.hIconSm,0  ;小图标
	
	;注册窗口类
	invoke RegisterClassEx, ADDR wc
	
	;创建窗口
	invoke CreateWindowEx,NULL,ADDR szClassName,offset szWindowTitle,
		WS_OVERLAPPEDWINDOW,  ;窗口样式
		200, 200, 400, 200,    ;窗口位置和大小
		NULL,NULL,hInst,NULL   ;父窗口、菜单、实例、参数
	mov hWnd,eax  ;保存窗口句柄
	
	;显示窗口
	invoke ShowWindow,hWnd,SW_SHOWNORMAL
	
	;更新窗口
	invoke UpdateWindow,hWnd
	
	;消息循环
	StartLoop:
		;获取消息
		invoke GetMessage,ADDR msg,NULL,0,0
		cmp eax, 0  ;检查是否退出消息循环
		je ExitLoop
			;翻译消息
			invoke TranslateMessage, ADDR msg
			;分发消息
			invoke DispatchMessage, ADDR msg
		jmp StartLoop
	ExitLoop:
	
	;返回退出码
	mov eax,msg.wParam
	ret
WinMain endp

; 窗口过程函数
; 处理窗口的所有消息
; 参数:
; hWin: 窗口句柄
; uMsg: 消息类型
; wParam: 消息参数1
; lParam: 消息参数2
WndProc proc hWin:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD
	LOCAL sysTime:SYSTEMTIME  ;系统时间结构体，用于存储当前时间
	
	;消息处理分支
	.if uMsg==WM_CREATE  ;窗口创建消息
		;创建时间显示静态文本控件
		invoke CreateWindowEx,NULL,addr szClassNameStatic,offset szTimeLabel,
			WS_CHILD or WS_VISIBLE or SS_LEFT,  ;控件样式
			50, 50, 200, 25,                   ;控件位置和大小
			hWin, IDC_TIME_STATIC,             ; 父窗口、控件ID
			hInstance, NULL                    ; 实例、参数
		mov hTimeStatic, eax  ; 保存控件句柄
		
		; 设置定时器，每秒更新一次时间
		invoke SetTimer,hWin,1,1000,NULL
		mov timerID, eax  ; 保存定时器ID
		
	.elseif uMsg == WM_TIMER  ; 定时器消息
		; 获取当前系统时间
		invoke GetLocalTime,ADDR sysTime
		
		; 格式化时间字符串 (时:分:秒)
		; 将时间分量零扩展为DWORD类型
		movzx eax,sysTime.wHour   ; 获取小时
		movzx ebx,sysTime.wMinute ; 获取分钟
		movzx ecx,sysTime.wSecond ; 获取秒
		; 使用wsprintf函数格式化时间字符串
		invoke wsprintf,ADDR szTimeBuffer,offset szTimeFormat,eax,ebx,ecx
		
		; 更新静态文本控件显示
		invoke SetWindowText,hTimeStatic,ADDR szTimeBuffer
		
	.elseif uMsg == WM_DESTROY  ; 窗口销毁消息
		; 销毁定时器
		invoke KillTimer,hWin,timerID
		; 发送退出消息
		invoke PostQuitMessage,NULL
	.else
		; 处理其他消息
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
	.endif
	ret
WndProc endp

END START  ; 程序结束点