.pragma library

function normalize(value) {
    if (value === null || value === undefined)
        return "";
    return String(value).toLowerCase();
}

function scoreToken(field, token) {
    if (token.length === 0)
        return 0;

    const text = normalize(field);
    const directIndex = text.indexOf(token);
    if (directIndex !== -1)
        return directIndex;

    let lastIndex = -1;
    let gapPenalty = 0;

    for (let i = 0; i < token.length; i++) {
        const nextIndex = text.indexOf(token.charAt(i), lastIndex + 1);
        if (nextIndex === -1)
            return -1;
        gapPenalty += nextIndex - lastIndex - 1;
        lastIndex = nextIndex;
    }

    return 100 + gapPenalty + Math.max(0, text.length - token.length);
}

function scoreCandidate(fields, query) {
    const trimmed = normalize(query).trim();
    if (trimmed.length === 0)
        return 0;

    const tokens = trimmed.split(/\s+/);
    let total = 0;

    for (let i = 0; i < tokens.length; i++) {
        let best = -1;
        for (let j = 0; j < fields.length; j++) {
            const score = scoreToken(fields[j], tokens[i]);
            if (score >= 0 && (best === -1 || score < best))
                best = score;
        }
        if (best === -1)
            return -1;
        total += best;
    }

    return total;
}
