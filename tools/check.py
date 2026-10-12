"""Check the game without Roblox Studio (Python 3, no extra packages).

  python tools/check.py            lint every script in src/ and run tools/tests/*.luau
  python tools/check.py --lint     only the lint

The first run downloads the official Luau tools (luau-lang/luau releases) into
tools/.luau/ (git-ignored). The lint finds syntax errors (luau-compile) and
misspelled names (luau-analyze "Unknown global", minus Roblox's own globals).
The tests run the shared modules (Config, Formulas, RewardInfo and the
ConfigParts) for real, with small stand-ins for Roblox objects; server and
client scripts still need a Studio playtest (see tools/studio-tests/).
"""
import io, pathlib, re, subprocess, sys, urllib.request, zipfile

TOOLS = pathlib.Path(__file__).resolve().parent
ROOT = TOOLS.parent
SRC = ROOT / "src"
LUAU_DIR = TOOLS / ".luau"
EXE = ".exe" if sys.platform == "win32" else ""
RELEASE = {"win32": "luau-windows.zip", "darwin": "luau-macos.zip"}.get(sys.platform, "luau-ubuntu.zip")

ROBLOX_GLOBALS = set("""game script workspace task warn print error Instance Vector3 Vector2 CFrame Color3 UDim UDim2 Enum Random
ColorSequence ColorSequenceKeypoint NumberSequence NumberSequenceKeypoint NumberRange TweenInfo Ray RaycastParams
OverlapParams Rect BrickColor Region3 tick time wait delay spawn typeof utf8 debug os Font PhysicalProperties DateTime
Axes Faces shared plugin settings UserSettings elapsedTime version require buffer bit32 SharedTable Path2DControlPoint
Vector3int16 Vector2int16 Region3int16 CatalogSearchParams FloatCurveKey RotationCurveKey DockWidgetPluginGuiInfo
gcinfo collectgarbage""".split())


def luau(tool):
    path = LUAU_DIR / (tool + EXE)
    if not path.exists():
        print("downloading the Luau tools (first run only)...")
        url = "https://github.com/luau-lang/luau/releases/latest/download/" + RELEASE
        data = urllib.request.urlopen(url, timeout=120).read()
        LUAU_DIR.mkdir(exist_ok=True)
        zipfile.ZipFile(io.BytesIO(data)).extractall(LUAU_DIR)
        for f in LUAU_DIR.iterdir():
            f.chmod(0o755)
    return str(path)


def rel(path):
    try:
        return path.resolve().relative_to(ROOT)
    except ValueError:
        return path


def lint(files):
    problems = 0
    for f in files:
        r = subprocess.run([luau("luau-compile"), "--null", str(f)], capture_output=True, text=True)
        errors = [line for line in (r.stdout + r.stderr).splitlines() if "Error" in line]
        if errors:
            problems += 1
            print("SYNTAX", rel(f), *errors, sep="\n  ")
        r = subprocess.run([luau("luau-analyze"), "--formatter=plain", str(f)], capture_output=True, text=True)
        for line in (r.stdout + r.stderr).splitlines():
            m = re.search(r":(\d+):\d+-\d+: \(\w+\) \w+: Unknown global '([^']+)'", line)
            if m and m.group(2) not in ROBLOX_GLOBALS:
                problems += 1
                print(f"TYPO?  {rel(f)}:{m.group(1)} unknown name '{m.group(2)}'")
    print(f"lint: {len(files)} files, {problems} problem(s)")
    return problems


# Roblox stand-ins for running the shared modules outside Studio
STUBS = r'''
local function cls(name)
	local mt = {}
	mt.__index = mt
	mt.__tostring = function() return name end
	return mt
end
local C3 = cls("Color3")
C3.Lerp = function(a, b, t) return setmetatable({ r = a.r + (b.r - a.r) * t, g = a.g + (b.g - a.g) * t, b = a.b + (b.b - a.b) * t }, C3) end
C3.ToHex = function(c) return string.format("%02X%02X%02X", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5)) end
Color3 = {
	new = function(r, g, b) return setmetatable({ r = r or 0, g = g or 0, b = b or 0 }, C3) end,
	fromRGB = function(r, g, b) return setmetatable({ r = (r or 0) / 255, g = (g or 0) / 255, b = (b or 0) / 255 }, C3) end,
	fromHSV = function() return setmetatable({ r = 1, g = 1, b = 1 }, C3) end,
}
Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, j) return k .. "." .. j end }) end })
local function value(...) return { ... } end
Vector3 = { new = value, zero = value(0, 0, 0) }
Vector2 = { new = value }
UDim2 = { new = value, fromOffset = value, fromScale = value }
UDim = { new = value }
NumberSequence = { new = value }
ColorSequence = { new = value }
NumberRange = { new = value }
warn = function(...) print("WARN", ...) end

-- a fake instance tree: WaitForChild / FindFirstChild by path; require() runs a module once
local Node = cls("Node")
local nodes = {}
function node(path)
	local n = nodes[path]
	if not n then
		n = setmetatable({ path = path, Name = path:match("[^/]+$") or path }, Node)
		nodes[path] = n
	end
	return n
end
Node.WaitForChild = function(self, name) return node(if self.path == "" then name else self.path .. "/" .. name) end
Node.FindFirstChild = Node.WaitForChild
Node.__index = function(self, k)
	if Node[k] then return Node[k] end
	if k == "Parent" then return node(self.path:match("^(.*)/[^/]+$") or "") end
	return nil
end
MODULES, CACHE = {}, {}
local realRequire = require
require = function(n)
	if type(n) == "table" and n.path then
		if CACHE[n.path] == nil then
			local f = MODULES[n.path]
			assert(f, "no module " .. n.path)
			CACHE[n.path] = f(n)
		end
		return CACHE[n.path]
	end
	return realRequire(n)
end
game = { GetService = function(_, name)
	if name == "ReplicatedStorage" then return node("") end
	return setmetatable({}, { __index = function() return function() end end })
end }
'''


def run_test(test):
    modules = {"Shared/" + p.stem: p for p in (SRC / "shared").glob("*.luau")
               if p.stem in ("Config", "Formulas", "RewardInfo")}
    for p in (SRC / "shared" / "ConfigParts").glob("*.luau"):
        modules["Shared/ConfigParts/" + p.stem] = p
    parts = [STUBS]
    for path, file in modules.items():
        parts.append(f'MODULES["{path}"] = function(script)\n{file.read_text(encoding="utf-8")}\nend\n')
    parts.append(test.read_text(encoding="utf-8"))
    bundle = LUAU_DIR / "bundle.luau"
    bundle.write_text("\n".join(parts), encoding="utf-8")
    r = subprocess.run([luau("luau"), str(bundle)], capture_output=True, text=True, encoding="utf-8")
    out = r.stdout + r.stderr
    print(out.rstrip())
    return 0 if r.returncode == 0 and "ALL PASS" in out else 1


def main():
    failed = lint(sorted(SRC.rglob("*.luau")) + sorted((TOOLS / "studio-tests").glob("*.luau")))
    if "--lint" not in sys.argv:
        for test in sorted((TOOLS / "tests").glob("*.luau")):
            print(f"\n== {test.name}")
            failed += run_test(test)
    print("\nOK" if failed == 0 else f"\n{failed} problem(s)")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
