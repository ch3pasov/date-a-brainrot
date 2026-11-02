local DateReveal = {}

-- A complete four-item demonstration lasts at least 3.2 seconds. Keeping an
-- explicit dark interval makes consecutive repeats separate, readable beats.
DateReveal.cueSeconds = .55
DateReveal.gapSeconds = .25
DateReveal.maxFrameSeconds = .1

local function sameSequence(a, b)
    if #a ~= #b then return false end
    for i, item in a do if item ~= b[i] then return false end end
    return true
end

function DateReveal.mount(sequence, token, previous)
    assert(type(sequence) == "table" and #sequence > 0, "A date reveal needs a sequence")
    if previous and previous.token == token and sameSequence(previous.sequence, sequence) then
        -- A new viewport has not shown the current phase yet. Replay that
        -- phase in full; retain completed beats and never restart a done reveal.
        previous.elapsed = 0
        return previous
    end
    return { token = token, sequence = table.clone(sequence), index = 1, phase = "cue", elapsed = 0, paused = false }
end

function DateReveal.current(state)
    return {
        index = state.index,
        total = #state.sequence,
        item = state.phase == "cue" and not state.paused and state.sequence[state.index] or nil,
        phase = state.phase,
        paused = state.paused == true,
        finished = state.phase == "done",
    }
end

function DateReveal.setPaused(state, paused)
    paused = paused == true
    if state.phase == "done" or state.paused == paused then return false end
    state.paused = paused
    -- An overlay can hide any part of this phase. Replay it in full after
    -- returning, without repeating earlier cues or consuming the next one.
    state.elapsed = 0
    state.resumeFramePending = not paused
    return true
end

function DateReveal.advance(state, delta)
    if state.phase == "done" or state.paused then return false end
    -- The first frame after an overlay closes includes time spent covered.
    if state.resumeFramePending then state.resumeFramePending = false; return false end
    if type(delta) ~= "number" or delta ~= delta or delta <= 0 then return false end
    -- A stalled/background frame must not consume unseen cues. Advance at
    -- most one phase and discard excess time rather than catching up to a clock.
    state.elapsed += math.min(delta, DateReveal.maxFrameSeconds)
    local duration = state.phase == "cue" and DateReveal.cueSeconds or DateReveal.gapSeconds
    if state.elapsed + 1e-9 < duration then return false end
    state.elapsed = 0
    if state.phase == "cue" then
        state.phase = "gap"
    elseif state.index < #state.sequence then
        state.index += 1; state.phase = "cue"
    else
        state.phase = "done"
    end
    return true
end

return DateReveal
