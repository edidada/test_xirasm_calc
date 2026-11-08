# test_xirasm_calc — XIRASM 科学计算器

用 [XIRASM 0.3.5](https://github.com/xir-kuku/XirAsm) 汇编写的 **Windows x86-64 PE64
控制台科学计算器**。输入来自 stdin，输出用 `printf`，数学运算用 SSE2 +
`msvcrt.dll` 导入，控制台输入用 Win32 `ReadFile`。不依赖 CRT 启动代码，
生成的可执行文件只有 28 KB。

## 构建

仓库自带汇编器 `tools/xirasm.exe` 和所需的标准库子集 `include/`，CI 无需联网下载：

```powershell
./tools/xirasm.exe build
# -> build/app.exe
```

`xirasm.toml` 指定 `src/main.xir` 为入口、`build/app.exe` 为产物。

## 运行

每行一个命令，三种模式：

| 输入 | 作用 |
| --- | --- |
| `2+3*4` | 表达式求值，输出 `2+3*4 = 14` |
| `table 0.5` | 打印该数的科学函数表（sin/cos/tan/…/x^2/x^3/1/x） |
| `selftest` | 运行 23 个内置用例，逐条打印 `PASS`/`FAIL` |
| （stdin 为空） | 自动运行内置自检 |

```powershell
Get-Content scripts/input.txt | ./build/app.exe
./build/app.exe < NUL          # 空输入触发自检
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
`call_func` 按 code 分派到 SSE2 指令或 `msvcrt.dll` 导入。

输出格式串、自检期望值（IEEE-754 位模式）和函数表行全部由 XIRASM 编译期
`for` 循环生成，产物里只有机器码与数据。

## 仓库结构

```
src/main.xir              计算器源码
xirasm.toml               构建配置
tools/xirasm.exe          随仓库入库的 0.3.5 汇编器
include/format/           标准格式库子集（PE/ELF/COFF/Mach-O facade）
include/io/               Windows 控制台 IO 库子集
scripts/input.txt         CI 测试输入
scripts/verify.ps1        构建后运行三种模式并断言输出/退出码
.github/workflows/ci.yml  GitHub Actions（windows-2022）
```

## CI

push 到 `main`、PR 或手动 `workflow_dispatch` 触发 `ci.yml`。工作流行：

1. `./tools/xirasm.exe build` 汇编；
2. `./scripts/verify.ps1` 跑表达式/函数表/自检三种模式，断言关键输出与
   退出码 0，并用空 stdin 再跑一次自检；
3. 上传 `build/app.exe` 作为 artifact。

查看日志：

```bash
gh run list --repo edidada/test_xirasm_calc
gh run watch
gh run view <run-id> --log
```
