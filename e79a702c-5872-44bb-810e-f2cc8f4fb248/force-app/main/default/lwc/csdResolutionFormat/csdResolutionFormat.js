/**
 * Format average resolution (hours) for dashboard KPIs.
 * Rules: &lt;24h → "4h 30m"; exactly 24h → "24h"; &gt;24h → fractional days (2 decimals).
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
    const days = h / 24;
    return `${days.toFixed(2)}d`;
}
