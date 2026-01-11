require("full-border"):setup()
function Linemode:size_and_mtime()
    local year = os.date("%Y")
    local mtime = self._file.cha.mtime
    local time_str = ""
    
    if mtime and mtime > 0 then
        local t = mtime // 1
        if os.date("%Y", t) == year then
            time_str = os.date("%b %d %H:%M", t)
        else
            time_str = os.date("%b %d  %Y", t)
        end
    end
    
    local size = self._file:size()
    return ui.Line(string.format(" %s %s ", size and ya.readable_size(size) or "-", time_str))
end

Status:children_add(function(self)
	local h = self._current.hovered
	if h and h.link_to then
		return " -> " .. tostring(h.link_to)
	else
		return ""
	end
end, 3300, Status.LEFT)
