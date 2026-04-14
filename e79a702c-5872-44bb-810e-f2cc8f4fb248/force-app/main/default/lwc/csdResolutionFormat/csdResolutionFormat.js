/**
 * Format average resolution (hours) for dashboard KPIs.
 * Rules: &lt;24h → "4h 30m"; exactly 24h → "24h"; &gt;24h → "xd yh zm" (days, hours, minutes).
 */
export function formatAverageResolutionHours(hours) {
    if (hours == null || hours === undefined || Number.isNaN(Number(hours))) {
        return '\u2014';
    }
    const h = Number(hours);
    const totalMinutes = Math.round(h * 60);
    const minutesIn24h = 24 * 60;
    if (totalMinutes === minutesIn24h) {
        return '24h';
    }
    if (totalMinutes < minutesIn24h) {
        const hh = Math.floor(totalMinutes / 60);
        const mm = totalMinutes % 60;
        if (mm === 0) {
            return `${hh}h`;
        }
        return `${hh}h ${mm}m`;
    }
    // Convert to days, hours, minutes format
    const totalMinutesAll = Math.round(h * 60);
    const days = Math.floor(totalMinutesAll / (24 * 60));
    const remainingMinutes = totalMinutesAll % (24 * 60);
    const hh = Math.floor(remainingMinutes / 60);
    const mm = remainingMinutes % 60;

    // Build the display string
    let result = `${days}d`;
    if (hh > 0 || mm > 0) {
        if (hh > 0) {
            result += ` ${hh}h`;
        }
        if (mm > 0) {
            result += ` ${mm}m`;
        }
    }
    return result;
}
