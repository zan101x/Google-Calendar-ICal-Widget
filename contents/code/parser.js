/**
 * Parser de ICS para QML - zan101
 * Basado en RFC 5545 + análisis del ICS real de Google Calendar.
 *
 * Google Calendar exporta TODO como VEVENT.
 * Distinción real posible:
 *   TRANSP:OPAQUE      → Evento (ocupa tiempo en agenda)
 *   TRANSP:TRANSPARENT → Recordatorio / tarea añadida al calendario (no bloquea tiempo)
 */

function parseICS(icsText) {
    // Normalizar saltos de línea (Google usa \r\r\n)
    const lines = icsText.replace(/\r/g, '').split('\n');
    const events = [];
    let currentEvent = null;
    let insideAlarm = false;

    for (let i = 0; i < lines.length; i++) {
        let line = lines[i];

        // RFC 5545: líneas plegadas (continuation lines)
        while (i + 1 < lines.length && (lines[i+1].startsWith(' ') || lines[i+1].startsWith('\t'))) {
            line += lines[i+1].substring(1);
            i++;
        }

        line = line.trim();
        if (!line) continue;

        // Ignorar el contenido dentro de VALARM
        if (line === 'BEGIN:VALARM') { insideAlarm = true; continue; }
        if (line === 'END:VALARM')   { insideAlarm = false; continue; }
        if (insideAlarm) continue;

        if (line === 'BEGIN:VEVENT' || line === 'BEGIN:VTODO') {
            currentEvent = {
                // Por defecto: VTODO = Tarea, VEVENT = Evento (se puede sobrescribir con TRANSP)
                type: line === 'BEGIN:VTODO' ? 'Tarea' : 'Evento'
            };
        } else if (line === 'END:VEVENT' || line === 'END:VTODO') {
            if (currentEvent && currentEvent.dtstart) {
                events.push(currentEvent);
                if (currentEvent.rrule) {
                    expandRecurringEvent(currentEvent, events);
                }
            }
            currentEvent = null;
        } else if (currentEvent) {
            const colonIdx = line.indexOf(':');
            if (colonIdx === -1) continue;

            const keyPart = line.substring(0, colonIdx);
            const value   = line.substring(colonIdx + 1);
            const key     = keyPart.split(';')[0].toUpperCase();

            switch (key) {
                case 'SUMMARY':
                    currentEvent.summary = cleanValue(value);
                    break;
                case 'DESCRIPTION':
                    currentEvent.description = cleanValue(value);
                    break;
                case 'LOCATION':
                    currentEvent.location = cleanValue(value);
                    break;
                case 'DTSTART':
                case 'DUE':
                    currentEvent.dtstart = parseDate(value, keyPart);
                    break;
                case 'DTEND':
                    currentEvent.dtend = parseDate(value, keyPart);
                    break;
                case 'RRULE':
                    currentEvent.rrule = value;
                    break;
                case 'TRANSP':
                    // TRANSPARENT = no bloquea tiempo = Tarea
                    if (value.trim().toUpperCase() === 'TRANSPARENT') {
                        currentEvent.type = 'Tarea';
                    }
                    break;
                case 'STATUS':
                    currentEvent.status = value.trim().toUpperCase();
                    break;
                default:
                    break;
            }
        }
    }

    events.sort((a, b) => a.dtstart - b.dtstart);
    return events;
}

function expandRecurringEvent(event, eventsArray) {
    const today = new Date();
    today.setHours(0, 0, 0, 0); // Consideramos todo el día de hoy
    const limitDate = new Date();
    limitDate.setMonth(today.getMonth() + 2);

    let freq = 'DAILY';
    let interval = 1;
    event.rrule.split(';').forEach(part => {
        if (part.startsWith('FREQ='))     freq     = part.substring(5);
        if (part.startsWith('INTERVAL=')) interval = parseInt(part.substring(9));
    });

    let nextStart = new Date(event.dtstart.getTime());
    let nextEnd   = event.dtend ? new Date(event.dtend.getTime()) : null;

    let iterations = 0;
    while (nextStart < limitDate && iterations < 100) {
        iterations++;
        if (freq === 'DAILY') {
            nextStart.setDate(nextStart.getDate() + interval);
            if (nextEnd) nextEnd.setDate(nextEnd.getDate() + interval);
        } else if (freq === 'WEEKLY') {
            nextStart.setDate(nextStart.getDate() + 7 * interval);
            if (nextEnd) nextEnd.setDate(nextEnd.getDate() + 7 * interval);
        } else if (freq === 'MONTHLY') {
            nextStart.setMonth(nextStart.getMonth() + interval);
            if (nextEnd) nextEnd.setMonth(nextEnd.getMonth() + interval);
        } else if (freq === 'YEARLY') {
            nextStart.setFullYear(nextStart.getFullYear() + interval);
            if (nextEnd) nextEnd.setFullYear(nextEnd.getFullYear() + interval);
        } else break;

        if (nextStart >= today) {
            const newEvent = Object.assign({}, event);
            newEvent.dtstart = new Date(nextStart.getTime());
            newEvent.dtstart.isAllDay = event.dtstart.isAllDay;
            if (nextEnd) {
                newEvent.dtend = new Date(nextEnd.getTime());
                newEvent.dtend.isAllDay = event.dtend ? event.dtend.isAllDay : false;
            }
            eventsArray.push(newEvent);
        }
    }
}

function cleanValue(val) {
    if (!val) return '';
    return val.replace(/\\n/g, '\n').replace(/\\,/g, ',').replace(/\\;/g, ';').replace(/\\\\/g, '\\');
}

function parseDate(val, keyPart) {
    const dateStr = val.trim();
    const isAllDay = keyPart.includes('VALUE=DATE') || dateStr.length === 8;

    if (dateStr.length >= 8) {
        const year  = parseInt(dateStr.substring(0, 4));
        const month = parseInt(dateStr.substring(4, 6)) - 1;
        const day   = parseInt(dateStr.substring(6, 8));

        if (dateStr.includes('T')) {
            const hour = parseInt(dateStr.substring(9, 11));
            const min  = parseInt(dateStr.substring(11, 13));
            const sec  = parseInt(dateStr.substring(13, 15));
            const d = dateStr.endsWith('Z')
                ? new Date(Date.UTC(year, month, day, hour, min, sec))
                : new Date(year, month, day, hour, min, sec);
            return d;
        } else {
            const d = new Date(year, month, day);
            d.setHours(0, 0, 0, 0);
            d.isAllDay = true;
            return d;
        }
    }
    return null;
}

function isToday(date) {
    if (!date) return false;
    const t = new Date();
    return date.getDate()     === t.getDate()  &&
           date.getMonth()    === t.getMonth() &&
           date.getFullYear() === t.getFullYear();
}
