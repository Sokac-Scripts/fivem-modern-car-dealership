let vehicles = [];
let selectedIndex = 0;

const BRAND_LOGOS = {
    lamborghini: { src: 'logo_lambo.png' },
    lambo: { src: 'logo_lambo.png' },
    porsche: { src: 'logo_porsche.png' },
    bmw: { src: 'logo_bmw.png' },
    audi: { src: 'logo_audi.png' },
    mercedes: { src: 'logo_mercedes.png' },
    volswagen: { src: 'logo_volkswagen.svg' },
    volkswagen: { src: 'logo_volkswagen.svg' },
    vw: { src: 'logo_volkswagen.svg' }
};const BRAND_X = [200, 363, 527, 703, 876, 1040, 1204];
const CARD_X = [183, 423, 693, 964, 1209];
const DEFAULT_COLOR = [255, 255, 255];

let brandList = [];
let brandIdx = 0;
let shown = [];

let actx = null;
function tone(f, d, type, vol, delay, slideTo) {
    try {
        const AC = window.AudioContext || window.webkitAudioContext;
        actx = actx || new AC();
        const t = actx.currentTime + (delay || 0);
        const o = actx.createOscillator(), g = actx.createGain();
        o.type = type || 'sine';
        o.frequency.setValueAtTime(f, t);
        if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + d);
        g.gain.setValueAtTime(vol || 0.05, t);
        g.gain.exponentialRampToValueAtTime(0.0001, t + d);
        o.connect(g); g.connect(actx.destination);
        o.start(t); o.stop(t + d);
    } catch (e) {}
}
const sfx = {
    tick: () => tone(900, 0.05, 'square', 0.025),
    brand: () => tone(450, 0.1, 'triangle', 0.05, 0, 850),
    open: () => { tone(500, 0.08, 'sine', 0.05); tone(760, 0.12, 'sine', 0.05, 0.07); },
    back: () => tone(620, 0.1, 'sine', 0.05, 0, 380),
    pay: () => tone(720, 0.07, 'triangle', 0.05),
    color: () => tone(1100, 0.05, 'sine', 0.035),
    buy: () => [523, 659, 784, 1046].forEach((f, i) => tone(f, 0.2, 'sine', 0.06, i * 0.09))
};

const post = (name, body) => fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', body: JSON.stringify(body) });

function buildBrands() {
    brandList = [];
    vehicles.forEach(v => {
        const key = String(v.brand).toLowerCase();
        if (!brandList.some(b => b.key === key)) brandList.push({ key, name: v.brand });
    });
}

let cardsDir = 0, brandsDir = 0, cardsEnterDir = 0, cardsDirOut = 0;

function restartAnim(el, name) {
    el.style.animation = 'none';
    void el.offsetWidth;
    el.style.animation = name + ' .32s ease-out';
}

function selectVehicle(globalIdx) {
    cardsDir = Math.sign(shown.indexOf(globalIdx) - shown.indexOf(selectedIndex));
    selectedIndex = globalIdx;
    if (cardsDir) sfx.tick();
    cardsEnterDir = cardsDir;
    cardsDirOut = cardsDir;
    renderCards();
    post('previewVehicle', { model: vehicles[globalIdx].model });
}

function selectBrand(i) {
    if (!brandList.length) return;
    const oldBrand = brandIdx;
    brandIdx = Math.max(0, Math.min(brandList.length - 1, i));
    brandsDir = Math.sign(brandIdx - oldBrand);
    if (brandsDir) sfx.brand();
    const key = brandList[brandIdx].key;
    cardEls.forEach(div => div.remove());
    cardEls.clear();
    shown = [];
    vehicles.forEach((v, gi) => { if (String(v.brand).toLowerCase() === key) shown.push(gi); });
    renderBrands();
    if (shown.length) selectVehicle(shown[0]);
}

function renderBrands() {
    const el = document.getElementById('brands');
    el.innerHTML = '';
    brandList.forEach((b, i) => {
        const d = i - brandIdx, slot = 3 + d;
        const div = document.createElement('div');
        div.className = 'brand' + (d === 0 ? ' sel' : '') + ((slot === 0 || slot === 6) ? ' far' : '') + ((slot < 0 || slot > 6) ? ' out' : '');
        div.style.left = BRAND_X[Math.max(0, Math.min(6, slot))] + 'px';
        div.style.top = (d === 0 ? 0 : 14) + 'px';
        const logo = BRAND_LOGOS[b.key];
        let icon = `<div class="ph">${b.name.charAt(0).toUpperCase()}</div>`;
        if (logo) icon = `<img class="lg" src="img/${logo.src}">`;
        div.innerHTML = icon + `<div class="nm">${b.name}</div>`;
        div.onclick = () => selectBrand(i);
        el.appendChild(div);
    });
    if (brandsDir) { restartAnim(el, brandsDir > 0 ? 'brandsNext' : 'brandsPrev'); brandsDir = 0; }
    const sn = document.getElementById('serie-name');
    if (sn && brandList[brandIdx]) sn.innerText = brandList[brandIdx].name.toUpperCase();
}

const cardEls = new Map();

function renderCards() {
    const el = document.getElementById('cards');
    const pos = shown.indexOf(selectedIndex);
    const want = new Set();
    for (let d = -2; d <= 2; d++) {
        const p = pos + d;
        if (p < 0 || p >= shown.length) continue;
        const gi = shown[p], v = vehicles[gi];
        want.add(gi);
        let div = cardEls.get(gi);
        const cls = 'card' + (d === 0 ? ' sel' : '') + (Math.abs(d) === 2 ? ' far' : '');
        const x = CARD_X[d + 2];
        if (!div) {
            div = document.createElement('div');
            div.innerHTML = `<div class="in"><img src="img/${v.img}" alt="car"><div class="t"><b>${v.name}</b><small>${v.brand}</small></div><div class="pr">$${v.price.toLocaleString()}</div><div class="bt">[X]&nbsp;&nbsp;Select</div></div>`;
            div.onclick = () => { if (gi !== selectedIndex) selectVehicle(gi); else openDetail(); };
            div.className = cls;

            div.style.left = (x + (cardsEnterDir || (d < 0 ? -1 : 1)) * 140) + 'px';
            div.style.opacity = '0';
            div.style.pointerEvents = 'auto';
            el.appendChild(div);
            void div.offsetWidth;
            cardEls.set(gi, div);
        }
        div.className = cls;
        div.style.left = x + 'px';
        div.style.opacity = '';
    }
    cardEls.forEach((div, gi) => {
        if (want.has(gi)) return;
        cardEls.delete(gi);
        div.style.pointerEvents = 'none';
        div.style.opacity = '0';
        div.style.left = (parseFloat(div.style.left) + (-cardsDirOut) * 140) + 'px';
        setTimeout(() => div.remove(), 380);
    });
    cardsDir = 0;
    document.querySelector('#pl span').innerText = `Vehicle List ${pos + 1}/${shown.length}`;
}
function moveVehicle(a) {
    const pos = shown.indexOf(selectedIndex) + a;
    if (pos >= 0 && pos < shown.length) selectVehicle(shown[pos]);
}

const COLORS = [
    { n: 'Silver Metallic', c: [170, 172, 175], metal: true },
    { n: 'Black', c: [10, 10, 10] },
    { n: 'Red', c: [215, 20, 20] },
    { n: 'Orange', c: [230, 115, 10] },
    { n: 'Yellow', c: [230, 175, 0] },
    { n: 'Green', c: [10, 205, 50] },
    { n: 'Blue', c: [0, 150, 255] },
    { n: 'Purple', c: [120, 50, 200] },
    { n: 'Pink', c: [235, 80, 160] },
    { n: 'White', c: [245, 245, 245] },
    { n: 'Brown', c: [110, 70, 40] }
];
let currentColor = COLORS[0].c;
let inDetail = false, colorMode = false;
const stageEl = document.getElementById('stage');
const colorsEl = document.getElementById('dt-colors');

function applyColor(rgb) {
    if (currentColor !== rgb) sfx.color();
    currentColor = rgb;
    post('changeColor', { primary: rgb, secondary: rgb });
    const sel = COLORS.find(c => c.c.join(',') === rgb.join(','));
    colorsEl.querySelectorAll('.dt-sw').forEach(s => s.classList.toggle('sel', s.dataset.c === rgb.join(',')));
    const nm = document.getElementById('dt-colorname');
    if (nm && sel) nm.innerText = sel.n.toUpperCase();
}
function openDetail() {
    const v = vehicles[selectedIndex];
    if (!v) return;
    document.getElementById('dt-name').innerText = v.name;
    document.getElementById('dt-desc').innerText = v.desc || `${v.brand} ${v.name} - pogledaj performanse, odaberi boju i kupi vozilo ili ga prvo isprobaj na test voznji.`;
    document.getElementById('dt-engine').innerText = v.engine + '/100';
    document.getElementById('dt-brakes').innerText = v.brakes + '/100';
    document.getElementById('dt-accel').innerText = v.accel + '/100';
    document.getElementById('dt-speed').innerText = v.speedVal + ' KMH';
    ['engine', 'brakes', 'speed', 'accel'].forEach(k => { document.getElementById('bar-' + k).style.width = '0%'; });
    setTimeout(() => {
        ['engine', 'brakes', 'speed', 'accel'].forEach(k => { document.getElementById('bar-' + k).style.width = (v[k] || 0) + '%'; });
    }, 80);
    document.getElementById('dt-price').innerText = '$' + v.price.toLocaleString();
    colorsEl.innerHTML = '<div class="dt-swrow"></div><div class="dt-colorname" id="dt-colorname"></div>';
    const row = colorsEl.querySelector('.dt-swrow');
    COLORS.forEach(col => {
        const s = document.createElement('div');
        s.className = 'dt-sw';
        s.dataset.c = col.c.join(',');
        s.style.background = col.metal
            ? 'linear-gradient(135deg,#e8e9ea,#8e9193 55%,#c4c6c8)'
            : `rgb(${col.c.join(',')})`;
        s.onclick = () => applyColor(col.c);
        row.appendChild(s);
    });
    colorMode = false;
    colorsEl.classList.remove('on');
    document.getElementById('detail').classList.remove('color-open');
    inDetail = true;
    sfx.open();
    stageEl.classList.add('detail-open');
    applyColor(currentColor);
}

function closeDetail() {
    if (inDetail) sfx.back();
    cancelConfirm();
    closePay();
    inDetail = false;
    colorMode = false;
    colorsEl.classList.remove('on');
    document.getElementById('detail').classList.remove('color-open');
    stageEl.classList.remove('detail-open');
}

function toggleColorMode() {
    colorMode = !colorMode;
    colorsEl.classList.toggle('on', colorMode);
    document.getElementById('detail').classList.toggle('color-open', colorMode);
}

function testDrive() {
    const v = vehicles[selectedIndex];
    if (v) post('testDrive', { model: v.model });
}

let payMode = false;
const detailEl = document.getElementById('detail');

function openPay() {
    const v = vehicles[selectedIndex];
    if (!v) return;
    payMode = true;
    sfx.pay();
    colorMode = false;
    colorsEl.classList.remove('on');
    detailEl.classList.remove('color-open');
    detailEl.classList.add('pay-open');
    document.getElementById('dt-payprice').innerHTML = 'Ukupno: <b>$' + v.price.toLocaleString() + '</b>';
}

function closePay() {
    payMode = false;
    detailEl.classList.remove('pay-open');
}

let confirmMode = false, pendingMethod = 'cash';

function askConfirm(method) {
    const v = vehicles[selectedIndex];
    if (!v) return;
    pendingMethod = method || 'cash';
    confirmMode = true;
    sfx.pay();
    document.getElementById('dt-confirmtext').innerHTML = 'Kupiti <b>' + v.name + '</b> za <b>$' + v.price.toLocaleString() + '</b><br>Nacin placanja: <b>' + (pendingMethod === 'bank' ? 'Bank' : 'Cash') + '</b>?';
    detailEl.classList.add('confirm-open');
}

function cancelConfirm() {
    confirmMode = false;
    detailEl.classList.remove('confirm-open');
}

document.getElementById('dt-yes').onclick = () => buyVehicle(pendingMethod);
document.getElementById('dt-no').onclick = () => cancelConfirm();

function buyVehicle(method) {
    const v = vehicles[selectedIndex];
    if (!v) return;
    cancelConfirm();
    closePay();
    sfx.buy();
    post('buyVehicle', {
        vehicle: v,
        payment: method || 'cash',
        colors: { primary: currentColor, secondary: currentColor }
    });
}

document.querySelectorAll('.dt-paybtn').forEach(el => {
    if (el.dataset.pay) el.onclick = () => askConfirm(el.dataset.pay);
});

document.querySelectorAll('.dt-key').forEach(el => {
    el.onclick = () => {
        const a = el.dataset.act;
        if (a === 'buy') openPay();
        else if (a === 'back') closeDetail();
        else if (a === 'color') toggleColorMode();
        else if (a === 'test') testDrive();
    };
});

function fitStage() {
    const st = document.getElementById('stage');
    const content = document.getElementById('content');

    const s = Math.min(window.innerWidth / 1403, window.innerHeight / 791);
    const W = window.innerWidth / s;
    const hs = window.innerHeight / s;
    st.style.transform = `scale(${s})`;
    st.style.left = '0px';
    st.style.width = W + 'px';
    st.style.height = hs + 'px';
    content.style.left = Math.max(0, (W - 1403) / 2) + 'px';
    content.style.height = hs + 'px';
    document.getElementById('cards').style.top = (hs - 150) + 'px';
    document.getElementById('pager').style.top = (hs - 185) + 'px';
    document.getElementById('detail').style.top = Math.max(70, hs - 480) + 'px';
}
document.getElementById('al').onclick = () => selectBrand(brandIdx - 1);
document.getElementById('ar').onclick = () => selectBrand(brandIdx + 1);
document.getElementById('pp').onclick = () => moveVehicle(-1);
document.getElementById('pn').onclick = () => moveVehicle(1);
window.addEventListener('resize', fitStage);
fitStage();

function parseColor(c) {
    if (!c) return null;
    let r, g, b;
    if (Array.isArray(c)) [r, g, b] = c;
    else if (typeof c === 'object') { r = c.r; g = c.g; b = c.b; }
    else {
        const str = String(c).trim();
        if (str[0] === '#') {
            let h = str.slice(1);
            if (h.length === 3) h = h.split('').map(x => x + x).join('');
            if (!/^[0-9a-fA-F]{6}$/.test(h)) return null;
            r = parseInt(h.slice(0, 2), 16); g = parseInt(h.slice(2, 4), 16); b = parseInt(h.slice(4, 6), 16);
        } else {
            const p = str.split(/[\s,]+/).map(Number);
            [r, g, b] = p;
        }
    }
    [r, g, b] = [r, g, b].map(n => Math.max(0, Math.min(255, Math.round(Number(n)))));
    return [r, g, b].some(isNaN) ? null : [r, g, b];
}

function applyAccent(color) {
    const rgb = parseColor(color);
    if (!rgb) return;
    const root = document.documentElement.style;
    root.setProperty('--accent', 'rgb(' + rgb.join(',') + ')');
    root.setProperty('--accent-rgb', rgb.join(', '));
}

window.addEventListener('message', function (event) {
    if (event.data.type === 'ui') {
        if (event.data.accent) applyAccent(event.data.accent);
        if (event.data.status) {
            if (event.data.vehicles) {
                vehicles = event.data.vehicles;
                selectedIndex = 0;
                buildBrands();
                fitStage();
                setTimeout(() => selectBrand(0), 100);
            }
            document.getElementById('app').style.display = 'flex';
        } else {
            closeDetail();
            document.getElementById('app').style.display = 'none';
        }
    }
});

document.addEventListener('keydown', function (event) {
    const k = event.key.toLowerCase();
    if (event.key === 'Tab') event.preventDefault();
    if (inDetail) {
        if (confirmMode) {
            if (event.key === 'Enter' || k === 'y') buyVehicle(pendingMethod);
            else if (event.key === 'Escape' || event.key === 'Delete' || event.key === 'Backspace' || k === 'n') cancelConfirm();
            return;
        }
        if (payMode) {
            if (event.key === '1' || k === 'c') askConfirm('cash');
            else if (event.key === '2' || k === 'b') askConfirm('bank');
            else if (event.key === 'Delete' || event.key === 'Backspace' || event.key === 'Escape') closePay();
            return;
        }
        if (event.key === 'Enter') openPay();
        else if (event.key === 'Delete' || event.key === 'Backspace' || event.key === 'Escape') closeDetail();
        else if (event.key === 'Control' && !event.repeat) toggleColorMode();
        else if (event.key === 'Tab') testDrive();
        else if (k === 'a') post('controlVehicle', { action: 'rotate', dir: 'left' });
        else if (k === 'd') post('controlVehicle', { action: 'rotate', dir: 'right' });
        return;
    }
    if (event.key === 'Escape') {
        document.getElementById('app').style.display = 'none';
        post('closeUI', {});
    } else if (event.key === 'ArrowLeft') {
        selectBrand(brandIdx - 1);
    } else if (event.key === 'ArrowRight') {
        selectBrand(brandIdx + 1);
    } else if (event.key === 'ArrowUp') {
        moveVehicle(-1);
    } else if (event.key === 'ArrowDown') {
        moveVehicle(1);
    } else if (k === 'x' || event.key === 'Enter') {
        openDetail();
    } else if (k === 'a') {
        post('controlVehicle', { action: 'rotate', dir: 'left' });
    } else if (k === 'd') {
        post('controlVehicle', { action: 'rotate', dir: 'right' });
    }
});

document.addEventListener('keyup', function (event) {
    const k = event.key.toLowerCase();
    if (k === 'a' || k === 'd') post('controlVehicle', { action: 'rotate', dir: 'stop' });
});

let dragging = false, lastX = 0;
document.addEventListener('mousedown', function (event) {
    if (event.button !== 0) return;
    if (event.target.closest('.card, .brand, .arr, #pager, .dt-key, .dt-colors, .dt-pay, .dt-confirm')) return;
    dragging = true;
    lastX = event.clientX;
    document.body.style.cursor = 'grabbing';
});
document.addEventListener('mousemove', function (event) {
    if (!dragging) return;
    const dx = event.clientX - lastX;
    lastX = event.clientX;
    if (dx) post('controlVehicle', { action: 'drag', dx: dx });
});
document.addEventListener('mouseup', function () {
    dragging = false;
    document.body.style.cursor = '';
});

document.addEventListener('wheel', function (event) {
    if (document.getElementById('app').style.display === 'flex') {
        post('controlVehicle', { action: 'zoom', dir: event.deltaY < 0 ? 'in' : 'out' });
    }
});
