-- rime/lua/fr_comment.lua
-- 在候选词右侧注释区显示该中文词对应的法语词。
-- 数据来自同目录下的 fr_data.lua（由 tools/emit_rime_lua.py 从 lexicon/zh_fr.tsv 生成）。
--
-- 注册方式（输入方案 engine/filters 内）：
--   - lua_filter@*fr_comment
--
-- ⚠ 硬规矩：本文件是**热路径**，每敲一键、每次候选刷新都会全量跑一遍。
--   这里**绝不允许**做任何磁盘/网络 I/O，也绝不允许 os.execute / io.popen 派生进程。
--   2026-10-05 在此加「高亮预取」确实会造成每次刷新派生一个 cmd 进程；
--   但用户侧卡顿的**真凶是 F2 按键路径里的 io.popen 同步等待**（见 fr_mt.lua 头部）。
--   两处都已改：外部动作只能脱离派生、且任何用户可感知路径都不得同步等待。

local loaded, FR = pcall(require, "fr_data")
if not loaded or type(FR) ~= "table" then
  FR = {}
end

-- 词性表（fr_pos.lua，由 tools/build_pos.py 从法汉汉法词典生成）：
-- 显示时在法语前拼接词性前缀（如 "m. téléphone portable"）。
-- Tab 上屏取 fr_data 的纯法语值，不受本表影响。
local ok_p, POS = pcall(require, "fr_pos")
if not ok_p or type(POS) ~= "table" then
  POS = {}
end

-- ── 可调项 ────────────────────────────────────────────────
local ENABLED     = true   -- 总开关：false 时完全不注入译词，恢复原生行为
local APPEND      = true   -- true 保留原注释（如五笔取码）并在其后追加；false 直接覆盖
local SEP         = "   "  -- 原注释与法语译词之间的分隔
local MAX_COMMENT = 64     -- 注释字节上限，超了就不加，避免撑破候选窗
-- ──────────────────────────────────────────────────────────

local function fr_comment(input, env)
  if not ENABLED then
    for cand in input:iter() do
      yield(cand)
    end
    return
  end

  for cand in input:iter() do
    local fr = FR[cand.text]
    if fr then
      local pos = POS[cand.text]
      local shown = pos and (pos .. " " .. fr) or fr
      local base = cand.comment or ""
      local comment
      if APPEND and base ~= "" then
        comment = base .. SEP .. shown
      else
        comment = shown
      end
      if #comment <= MAX_COMMENT then
        -- Candidate(type, start, end, text, comment)；end 是 Lua 关键字，故取 _end
        yield(Candidate(cand.type, cand.start, cand._end, cand.text, comment))
      else
        -- 注释超长时截断显示（保留主译），不丢弃，避免多义词无注释
        local cut = comment:sub(1, MAX_COMMENT - 3) .. "…"
        yield(Candidate(cand.type, cand.start, cand._end, cand.text, cut))
      end
    else
      yield(cand)
    end
  end
end

return fr_comment
