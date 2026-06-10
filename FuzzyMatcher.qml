import QtQuick

// fzy-style subsequence scorer (algorithm: https://github.com/jhawthorn/fzy).
// Pure functions, no state. Comparison is case-insensitive; callers pass
// pre-lowercased haystacks. Higher score = better match.
QtObject {
    function isSubsequence(needle, hay) {
        let j = 0;
        for (let i = 0; i < hay.length && j < needle.length; i++) {
            if (hay[i] === needle[j])
                j++;
        }
        return j === needle.length;
    }

    // Per-character word-boundary bonus: a matched char scores higher right
    // after a separator (path slash, space, dash/underscore, dot).
    function _bonusArray(hay) {
        const bonus = new Array(hay.length);
        let prev = "/";
        for (let j = 0; j < hay.length; j++) {
            const ch = hay[j];
            const alnum = (ch >= "a" && ch <= "z") || (ch >= "0" && ch <= "9");
            if (!alnum)
                bonus[j] = 0;
            else if (prev === "/")
                bonus[j] = 0.9;
            else if (prev === "-" || prev === "_" || prev === " ")
                bonus[j] = 0.8;
            else if (prev === ".")
                bonus[j] = 0.6;
            else
                bonus[j] = 0;
            prev = ch;
        }
        return bonus;
    }

    // Best alignment score via fzy's two-row dynamic program. Assumes needle is
    // a subsequence of hay (matchAll pre-checks); rewards consecutive runs and
    // boundary hits, penalises gaps.
    function _score(needle, hay, bonus) {
        const n = needle.length;
        const m = hay.length;
        const GAP_LEADING = -0.005;
        const GAP_INNER = -0.01;
        const GAP_TRAILING = -0.005;
        const CONSECUTIVE = 1.0;
        const MIN = Number.NEGATIVE_INFINITY;

        let prevD = new Array(m);
        let prevM = new Array(m);
        let currD = new Array(m);
        let currM = new Array(m);

        for (let i = 0; i < n; i++) {
            let rowBest = MIN;
            const gap = (i === n - 1) ? GAP_TRAILING : GAP_INNER;
            for (let j = 0; j < m; j++) {
                if (needle[i] === hay[j]) {
                    let s = MIN;
                    if (i === 0)
                        s = j * GAP_LEADING + bonus[j];
                    else if (j > 0)
                        s = Math.max(prevM[j - 1] + bonus[j], prevD[j - 1] + CONSECUTIVE);
                    currD[j] = s;
                    rowBest = Math.max(s, rowBest + gap);
                    currM[j] = rowBest;
                } else {
                    currD[j] = MIN;
                    rowBest = rowBest + gap;
                    currM[j] = rowBest;
                }
            }
            const td = prevD; prevD = currD; currD = td;
            const tm = prevM; prevM = currM; currM = tm;
        }
        return prevM[m - 1];
    }

    // Multi-token AND: every non-empty whitespace token must match hay as a
    // subsequence. Returns the summed score, or null if any token misses or no
    // usable token is given. Empty tokens are ignored (no score, no NaN).
    function matchAll(tokens, hay) {
        let matched = 0;
        for (let i = 0; i < tokens.length; i++) {
            const t = tokens[i];
            if (t.length === 0)
                continue;
            if (!isSubsequence(t, hay))
                return null;
            matched++;
        }
        if (matched === 0)
            return null;
        const bonus = _bonusArray(hay);
        let total = 0;
        for (let i = 0; i < tokens.length; i++) {
            const t = tokens[i];
            if (t.length > 0)
                total += _score(t, hay, bonus);
        }
        return total;
    }
}
