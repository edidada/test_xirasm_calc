# test_xirasm_calc — XIRASM 科学计算器（Linux x86-64 分支）

用 [XIRASM 0.3.5](https://github.com/xir-kuku/XirAsm) 汇编写的 **Linux x86-64
ELF64 控制台科学计算器**。输入来自 stdin（直接 `read(2)` syscall），输出用 libc
`printf`，数学运算用 SSE2 + libc/libm 动态导入，程序退出用 `exit(60)` syscall，
遵循 System V AMD64 ABI。

> **分支说明**：`main` 是 Windows x86-64 PE64 版本（Win64 ABI、`msvcrt.dll` 导入、
> Win32 `ReadFile`）；本分支 `linux-x86-64` 是 Linux/ELF64 版本。两个分支互不
> 影响，本分支不向 `main` 提 PR —— 否则原 Windows CI 会用 Windows runner 编译
> Linux 源码而失败。
>
> **本地不编译**：本仓库不在本地执行汇编，也不在本地 WSL 运行验证。汇编、运行、
> 输出校验全部由 GitHub Actions 完成，见下方 CI 章节。

## 构建

仓库自带汇编器 `tools/xirasm.exe`（Windows PE 程序）和所需的标准库子集
`include/`，CI 无需联网下载：

```powershell
./tools/xirasm.exe build
# -> build/app   (ELF64 可执行文件)
```

`xirasm.toml` 指定 `src/main.xir` 为入口、`build/app` 为产物，目标为
`os = "linux"` / `abi = "sysv"`。汇编器本身是 Windows 程序，但发射的是 ELF
字节，因此构建在 Windows runner 上完成，产物交到 Linux runner 上运行。

## 运行

每行一个命令，三种模式：

| 输入 | 作用 |
| --- | --- |
| `2+3*4` | 表达式求值，输出 `2+3*4 = 14` |
| `table 0.5` | 打印该数的科学函数表（sin/cos/tan/…/x^2/x^3/1/x） |
| `selftest` | 运行 23 个内置用例，逐条打印 `PASS`/`FAIL` |
| （stdin 为空） | 自动运行内置自检 |

```bash
./build/app < scripts/input.txt
./build/app < /dev/null       # 空输入触发自检
```

程序正常结束退出码为 0；任一自检用例失败则退出码为 1。

## 表达式语法

- 运算符：`+ - * / ^`，一元 `+`/`-`，括号；`^` 右结合，优先级高于一元负号
  （`-2^2 = -4`，`2^3^2 = 512`）。
- 数字：`strtod` 解析，支持小数与科学计数法（`1e3`）。
- 常量：`pi`、`e`、`tau`。
- 一元函数（19 个）：
  `sin cos tan asin acos atan sinh cosh tanh sqrt abs exp ln log log10
  floor ceil deg rad`，均写作 `name(expr)`。

示例：

```
sin(pi/6) = 0.5
2*(3+4)-5/2 = 11.5
sin(cos(0)) = 0.8414709848
rad(180) = 3.141592654
```

## 实现要点

`src/main.xir` 是递归下降解析器（`parse_expr` → `parse_term` → `parse_unary` →
`parse_power` → `parse_atom`），值在 `xmm0` 中返回。标识符在汇编期生成一张
16 字节/项的查找表，运行期把名字压成一个 8 字节小端 key 查表。每个函数由
`call_func` 按 code 分派到 SSE2 指令或 libc/libm 导入。

外部符号通过 ELF GOT slot 导入（`format_elfexe_import_slots_mut`），slot 标签名
就是符号名，因此 `call [rel printf]`、`call [rel sin]` 等写法与 Windows 版一致。
System V ABI 下 `rsi` 是易失寄存器，而它是解析器的共享输入指针，所以在
`call_func` 和 `pow` 调用处用栈帧保存/恢复。

输出格式串、自检期望值（IEEE-754 位模式）和函数表行全部由 XIRASM 编译期
`for` 循环生成，产物里只有机器码与数据。

## 仓库结构

```
src/main.xir              计算器源码
xirasm.toml               构建配置（ELF64 / sysv）
tools/xirasm.exe          随仓库入库的 0.3.5 汇编器（Windows 程序）
include/format/           标准格式库子集（PE/ELF/COFF/Mach-O facade）
include/io/               Linux 控制台 IO 库子集（纯 syscall）
scripts/input.txt         CI 测试输入
scripts/verify.ps1        main 分支的 Windows 校验脚本
scripts/verify.sh         本分支的 Linux 校验脚本
.github/workflows/ci.yml           main 分支的 Windows CI
.github/workflows/ci-linux.yml     本分支的两阶段 CI
```

## CI

push 到 `linux-x86-64` 或手动 `workflow_dispatch` 触发 `ci-linux.yml`。
因为汇编器是 Windows 程序而产物是 Linux 可执行文件，工作流分两个阶段：

1. **assemble**（`windows-2022`）：`./tools/xirasm.exe build` 汇编出
   `build/app`，用 `actions/upload-artifact@v4` 上传。
2. **verify**（`ubuntu-latest`）：下载产物并 `chmod +x`（artifact 经 zip 不保留
   可执行位），用 `file` / `readelf` / `ldd` 输出结构诊断，然后跑
   `bash scripts/verify.sh` 校验表达式、函数表、自检三种模式的输出与退出码。

查看日志：

```bash
gh run list --repo edidada/test_xirasm_calc
gh run watch
gh run view <run-id> --log
```
