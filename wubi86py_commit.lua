-- rime/lua/wubi86py_commit.lua
-- 「五笔86·拼音」方案专用副本：仅保留 Tab 词级法文上屏（空格中文/回车原码/Tab 法文）。
-- 与 fr_commit.lua 的差异只有 SENT_KC = nil（禁用 F2 句级，用户未要求；frime 不受影响）。
-- 法文上屏：按一个键，把当前高亮候选对应的法语直接送进应用，而不是中文。
-- 与 fr_comment.lua 同一份词库（fr_data.lua），所以「看得见就一定打得出来」。
--
-- 注册方式（输入方案 engine/processors 内，必须排在 selector 之前）：
--   - lua_processor@*fr_commit

local loaded, FR = pcall(require, "fr_data")
if not loaded or type(FR) ~= "table" then
  FR = {}
end

-- ── 可调项 ────────────────────────────────────────────────
local ENABLED   = true
local COMMIT_KC = 0xff09   -- 词级上屏键，0xff09 = Tab
local SENT_KC   = nil      -- 本方案仅词级（Tab）；F2 句级上屏留给 frime
  -- 想换键就改这个十六进制 keysym：
  --   F2 = 0xffbf   F3 = 0xffc0   Escape = 0xff1b
  --   Control+g 之类组合键请改下面 key:ctrl()/key:alt() 的判断
local SPLIT     = " / "    -- 多义项只提交第一个，避免把整串释义送进正文
-- ──────────────────────────────────────────────────────────

local kAccepted = 1
local kNoop = 2

local function first_sense(fr)
  local cut = string.find(fr, SPLIT, 1, true)
  if cut then return (string.gsub(string.sub(fr, 1, cut - 1), "^%s*(.-)%s*$", "%1")) end
  return fr
end

local ok_s, S = pcall(require, "fr_sentence")
if not ok_s or type(S) ~= "table" then S = nil end

local ok_m, MT = pcall(require, "fr_mt")
if not ok_m or type(MT) ~= "table" then MT = nil end

-- 在线译文一律带此标记：机翻会犯只有人看得出的搭配错
-- （例：再上脚手架 → avant de *mettre* l'échaudage，该用 monter sur），
-- 不带标记就会被当范本背下来。规则引擎的输出不带标记。
local MT_MARK = " [m]"

-- 处理器里绝不能让异常抛回 RIME：未捕获的 Lua 错误会污染按键流水线，
-- 表现就是输入法卡顿或行为异常。所有外部调用一律包 pcall。
local function safe(fn, ...)
  if not fn then return nil end
  local ok, res = pcall(fn, ...)
  return ok and res or nil
end

local function fr_commit(key, env)
  if not ENABLED or key:release() then return kNoop end
  local want = nil
  if key.keycode == COMMIT_KC then want = "word"
  elseif SENT_KC and key.keycode == SENT_KC then want = "sentence" end
  if not want then return kNoop end

  local ctx = env.engine.context
  if not ctx:is_composing() or not ctx:has_menu() then
    return kNoop            -- 没在输入中：把按键原样交还给应用去切焦点
  end

  local cand = ctx:get_selected_candidate()
  if not cand then return kNoop end

  local fr = FR[cand.text]

  if want == "sentence" then
    -- ① 规则引擎：0 延迟、语法可控、每句可解释
    local sent = safe(S and S.generate, cand.text)
    if sent and sent ~= "" then
      env.engine:commit_text(sent)
      ctx:clear()
      return kAccepted
    end
    -- ② 在线引擎：**只读缓存，不等待**。命中即用（带 [m] 标记）
    local on = safe(MT and MT.cached, cand.text)
    if on and on ~= "" then
      env.engine:commit_text(on .. MT_MARK)
      ctx:clear()
      return kAccepted
    end
    -- ③ 缓存没有 → 派一个脱离进程去取，本次立刻放弃；再按一次 F2 就有了。
    --    绝不在此同步等网络：上一次版本就是在这里 io.popen 把输入法挂住 1.5~8 秒，
    --    用户侧表现为「按 F2 才卡」。
    safe(MT and MT.request, cand.text, ctx)
    -- ④ 退回词级，让这次按键不白按
    if not fr then return kNoop end
  end

  if not fr or fr == "" then
    return kNoop            -- 该词没注释：同样不劫持按键
  end

  env.engine:commit_text(first_sense(fr))
  ctx:clear()               -- 关键：清空编码，否则中文会跟着一起上屏
  return kAccepted
end

return fr_commit
