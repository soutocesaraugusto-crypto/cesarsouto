// Gerador de desenho técnico — Misturador em V Alimentício
// Saída: tambor-v-desenho.svg
const fs = require('fs');

const OUT = __dirname + '/tambor-v-desenho.svg';

// ── Paleta ──────────────────────────────────────────────────────────────────
const C = {
  bg:     '#FAFAFA',
  body:   '#D6D6D6',
  face:   '#C2C2C2',
  side:   '#ABABAB',
  dark:   '#919191',
  line:   '#1A2744',
  dim:    '#555',
  red:    '#CC0000',
  shaft:  '#8B7030',
  brg:    '#2255AA',
  seal:   '#226622',
  title:  '#1A2744',
  grid:   '#E0E0E0',
};

// ── Helpers ──────────────────────────────────────────────────────────────────
const p2 = (x,y) => `${r(x)},${r(y)}`;
const r  = n  => Math.round(n*10)/10;
function poly(pts, fill, stroke, sw=1.5, extra='') {
  return `<polygon points="${pts.map(p=>p2(...p)).join(' ')}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" ${extra}/>`;
}
function rect(x,y,w,h,fill,stroke,sw=1.5,rx=0,extra='') {
  return `<rect x="${r(x)}" y="${r(y)}" width="${r(w)}" height="${r(h)}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" rx="${rx}" ${extra}/>`;
}
function circ(cx,cy,rad,fill,stroke,sw=1.5) {
  return `<circle cx="${r(cx)}" cy="${r(cy)}" r="${r(rad)}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;
}
function line(x1,y1,x2,y2,stroke,sw=1,dash='') {
  const d = dash ? `stroke-dasharray="${dash}"` : '';
  return `<line x1="${r(x1)}" y1="${r(y1)}" x2="${r(x2)}" y2="${r(y2)}" stroke="${stroke}" stroke-width="${sw}" ${d}/>`;
}
function txt(x,y,s,sz=12,anchor='middle',fill=C.line,weight='normal',italic=false) {
  const sty = italic ? 'font-style="italic"' : '';
  return `<text x="${r(x)}" y="${r(y)}" text-anchor="${anchor}" font-family="Arial,sans-serif" font-size="${sz}" fill="${fill}" font-weight="${weight}" ${sty}>${s}</text>`;
}
function arrow(x1,y1,x2,y2,label,offpx=24,side=1,fsz=11) {
  const dx=x2-x1, dy=y2-y1, len=Math.sqrt(dx*dx+dy*dy);
  const nx=-dy/len*side, ny=dx/len*side;
  const ox1=x1+nx*offpx, oy1=y1+ny*offpx;
  const ox2=x2+nx*offpx, oy2=y2+ny*offpx;
  const lx=(ox1+ox2)/2+nx*12, ly=(oy1+oy2)/2+ny*12;
  return [
    line(x1,y1, x1+nx*(offpx+2), y1+ny*(offpx+2), C.dim, 0.8, '4,3'),
    line(x2,y2, x2+nx*(offpx+2), y2+ny*(offpx+2), C.dim, 0.8, '4,3'),
    `<line x1="${r(ox1)}" y1="${r(oy1)}" x2="${r(ox2)}" y2="${r(oy2)}" stroke="${C.dim}" stroke-width="1" marker-start="url(#markerArr)" marker-end="url(#markerArr)"/>`,
    txt(lx,ly+4,label,fsz,'middle',C.dim)
  ].join('\n');
}

// ============================================================================
//  GEOMETRIA  — Tambor em V Prismático
//  Arm width  = 230 mm
//  Arm length = 430 mm (flange → vertex)
//  Depth      = 230 mm (profundidade, representado em perspectiva)
//  V angle    = 90°  (45° cada braço)
//  Scale      = 0.72 px/mm  → 430mm = 310px
// ============================================================================
const SC   = 0.72;
const mm   = v => v * SC;

// Isometric offsets (depth projection)
const ISO_DX = mm(230)*0.30;  // profundidade proj. em X
const ISO_DY = mm(230)*0.15;  // profundidade proj. em Y (para cima)

// ── Centro da vista principal ────────────────────────────────────────────────
const VX = 460, VY = 790;  // vertex (ponto mais baixo do V)

const cos45 = Math.cos(Math.PI/4);  // 0.7071
const sin45 = Math.sin(Math.PI/4);  // 0.7071

const ARM  = mm(430);  // 310 px
const HALF = mm(115);  // 82.8 px
const DEPTH= mm(230);  // 165.6 px

// Centros do topo de cada braço
const LTC = [VX - ARM*cos45, VY - ARM*sin45];  // left top center
const RTC = [VX + ARM*cos45, VY - ARM*sin45];  // right top center

// Perpendicular ao braço esquerdo (largura): aponta p/ fora do V
// Braço esq. vai em direção (-cos45, -sin45). Perp. externo = (-sin45, cos45) = PARA BAIXO-ESQ em SVG
const PL = [-sin45,  cos45];   // externo (esq)
const PI = [ sin45, -cos45];   // interno (centro)

// Faces frontais dos braços (4 cantos cada)
const LF = [
  [VX + PL[0]*HALF,         VY + PL[1]*HALF        ],  // vertex outer
  [LTC[0]+PL[0]*HALF,       LTC[1]+PL[1]*HALF      ],  // top outer
  [LTC[0]+PI[0]*HALF,       LTC[1]+PI[1]*HALF      ],  // top inner
  [VX + PI[0]*HALF,         VY + PI[1]*HALF        ],  // vertex inner
];

// Perpendicular ao braço direito
const PR = [ sin45,  cos45];
const PIR= [-sin45, -cos45];

const RF = [
  [VX + PIR[0]*HALF,        VY + PIR[1]*HALF       ],  // vertex inner
  [RTC[0]+PIR[0]*HALF,      RTC[1]+PIR[1]*HALF     ],  // top inner
  [RTC[0]+PR[0]*HALF,       RTC[1]+PR[1]*HALF      ],  // top outer
  [VX + PR[0]*HALF,         VY + PR[1]*HALF        ],  // vertex outer
];

// Faces superiores (topos dos braços) — perspectiva isométrica
function isoFace(frontCornerA, frontCornerB) {
  // retorna 4 cantos: frente-a, frente-b, trás-b, trás-a
  return [
    frontCornerA,
    frontCornerB,
    [frontCornerB[0]+ISO_DX, frontCornerB[1]-ISO_DY],
    [frontCornerA[0]+ISO_DX, frontCornerA[1]-ISO_DY],
  ];
}

// Topo braço esquerdo (entre top outer e top inner, versão traseira)
const L_topFace = isoFace(LF[1], LF[2]);
const R_topFace = isoFace(RF[1], RF[2]);

// Lateral esquerda externa (face lateral do braço esq.)
const L_sideFace = isoFace(LF[0], LF[1]);
const R_sideFace = isoFace(RF[2], RF[3]);

// ── Descarga (base do V) ─────────────────────────────────────────────────────
const DW = mm(80), DH = mm(50);
const discharge_front = [
  [VX - DW/2,       VY           ],
  [VX + DW/2,       VY           ],
  [VX + DW/2,       VY + DH      ],
  [VX - DW/2,       VY + DH      ],
];

// ── Flanges circulares no topo de cada braço ─────────────────────────────────
const FLANGE_R = mm(55);   // raio externo
const FLANGE_r = mm(18);   // raio interno (eixo)

// Tampas de limpeza em cada braço (2 por braço — retângulos sobre a face)
function cleanCover(armFace, frac1, frac2, w_frac) {
  // interpolação ao longo do braço
  const lerp = (a,b,t) => [a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t];
  const A1o = lerp(armFace[0], armFace[1], frac1);
  const A1i = lerp(armFace[3], armFace[2], frac1);
  const A2o = lerp(armFace[0], armFace[1], frac2);
  const A2i = lerp(armFace[3], armFace[2], frac2);
  // reduz largura pelo fator
  const mid1o = [A1o[0]+(A1i[0]-A1o[0])*(1-w_frac)/2, A1o[1]+(A1i[1]-A1o[1])*(1-w_frac)/2];
  const mid1i = [A1o[0]+(A1i[0]-A1o[0])*(1+w_frac)/2, A1o[1]+(A1i[1]-A1o[1])*(1+w_frac)/2];
  const mid2o = [A2o[0]+(A2i[0]-A2o[0])*(1-w_frac)/2, A2o[1]+(A2i[1]-A2o[1])*(1+w_frac)/2];
  const mid2i = [A2o[0]+(A2i[0]-A2o[0])*(1+w_frac)/2, A2o[1]+(A2i[1]-A2o[1])*(1-w_frac)/2];
  return [mid1o, mid2o, mid2i, mid1i];
}

const L_cover = cleanCover(LF, 0.28, 0.62, 0.65);
const R_cover = cleanCover(RF, 0.28, 0.62, 0.65);

// ============================================================================
//  VISTA EXPLODIDA — Eixo e componentes
//  Posicionada abaixo / lado direito
// ============================================================================
const EX = 920;   // x base da explodida
const EY = 200;   // y centro vertical
const SHAFT_L = mm(808);  // comprimento total do eixo
const SHAFT_R = mm(17.5); // raio do eixo (35mm diâmetro)
const BRG_L   = mm(22);   // largura do rolamento
const BRG_R   = mm(35);   // raio externo do rolamento
const MAN_L   = mm(55);   // comprimento do mancal
const MAN_R   = mm(50);   // raio externo do mancal
const DRUM_W  = mm(230);  // largura do tambor na vista explodida
const GAP     = mm(30);   // espaço entre componentes

// posições X dos componentes (centradas em EX + SHAFT_L/2)
const SX = EX;  // início do eixo
// Componentes da esquerda para direita:
// Mancal Esq | Rolamento Esq | [gap] | Tambor | [gap] | Rolamento Dir | Mancal Dir
const manL_x   = SX;
const brgL_x   = manL_x + MAN_L + GAP;
const drum_x   = brgL_x + BRG_L + GAP*2;
const brgR_x   = drum_x + DRUM_W + GAP*2;
const manR_x   = brgR_x + BRG_L + GAP;
const shaftEnd = manR_x + MAN_L + mm(30);

// ============================================================================
//  Montar SVG
// ============================================================================
const W_SVG = 1480, H_SVG = 1020;

const defs = `<defs>
  <marker id="markerArr" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto">
    <path d="M0,0 L0,8 L8,4 z" fill="${C.dim}"/>
  </marker>
  <filter id="shadow" x="-5%" y="-5%" width="115%" height="115%">
    <feDropShadow dx="3" dy="3" stdDeviation="3" flood-opacity="0.15"/>
  </filter>
</defs>`;

const bg = rect(0,0,W_SVG,H_SVG,C.bg,'none');
const gridLines = () => {
  let g = '';
  for(let x=0;x<W_SVG;x+=50) g += line(x,0,x,H_SVG,C.grid,0.4);
  for(let y=0;y<H_SVG;y+=50) g += line(0,y,W_SVG,y,C.grid,0.4);
  return g;
};

const titleBar = [
  rect(0,0,W_SVG,52,C.line,'none'),
  txt(W_SVG/2, 22, 'TAMBOR EM V — MISTURADOR ALIMENTÍCIO  |  AISI 316L  |  Capacidade 15–20 kg', 15,'middle','white','bold'),
  txt(W_SVG/2, 43, 'Vista Principal + Vista Explodida do Conjunto de Eixo  ·  Escala aprox. 1:1,4  ·  Cotas em mm', 11,'middle','#AAC4FF'),
].join('\n');

// ── Vista Principal ──────────────────────────────────────────────────────────
const mainViewLabel = txt(240, 90, 'VISTA PRINCIPAL (Frente)', 13, 'middle', C.title, 'bold');
const divLine = line(820, 55, 820, H_SVG-20, '#CCC', 0.8, '8,4');

// Faces da vista principal (ordem: fundo → frente)
const views = [
  // Faces traseiras (ISO) — mais escuras
  poly(L_topFace, C.side, C.line, 1),
  poly(R_topFace, C.side, C.line, 1),
  poly(L_sideFace, C.dark, C.line, 1),
  poly(R_sideFace, C.dark, C.line, 1),

  // Faces frontais dos braços
  poly(LF, C.body, C.line, 1.8),
  poly(RF, C.body, C.line, 1.8),

  // Descarga (base do V)
  poly(discharge_front, C.side, C.line, 1.5),
  // Borda inferior da descarga (perspectiva)
  poly([
    discharge_front[2],
    discharge_front[3],
    [discharge_front[3][0]+ISO_DX*0.5, discharge_front[3][1]-ISO_DY*0.5],
    [discharge_front[2][0]+ISO_DX*0.5, discharge_front[2][1]-ISO_DY*0.5],
  ], C.dark, C.line, 1),

  // Tampas de limpeza
  poly(L_cover, '#BFBFBF', C.line, 1.5),
  poly(R_cover, '#BFBFBF', C.line, 1.5),

  // Flanges circulares no topo dos braços
  // Esq
  circ(LTC[0], LTC[1], FLANGE_R, '#E0E0E0', C.line, 2),
  circ(LTC[0], LTC[1], FLANGE_r, '#888', C.line, 1.5),
  // Dir
  circ(RTC[0], RTC[1], FLANGE_R, '#E0E0E0', C.line, 2),
  circ(RTC[0], RTC[1], FLANGE_r, '#888', C.line, 1.5),

  // Anéis/alças no topo (handles)
  circ(LTC[0]-FLANGE_R, LTC[1]-10, mm(12), 'none', C.line, 2),
  circ(RTC[0]+FLANGE_R, RTC[1]-10, mm(12), 'none', C.line, 2),
].join('\n');

// ── Cotas da vista principal ─────────────────────────────────────────────────

// 1. Largura do braço (230mm) — entre os lados de LF
const dimArmWidth = arrow(LF[0][0], LF[0][1], LF[3][0], LF[3][1], '230', 28, 1, 11);

// 2. Comprimento do braço (430mm) — ao longo do braço esq. (outer)
const dimArmLen = arrow(LF[0][0], LF[0][1], LF[1][0], LF[1][1], '430', 28, -1, 11);

// 3. Ângulo do V = 90°
const angLabel = txt(VX, VY-30, '90°', 13, 'middle', C.red, 'bold');
// Arco do ângulo
const angArc = `<path d="M ${r(VX-50)} ${r(VY-30)} A 60 60 0 0 1 ${r(VX+50)} ${r(VY-30)}" fill="none" stroke="${C.red}" stroke-width="1.5"/>`;

// 4. Profundidade (230mm) — offset isométrico
const depthLine = [
  line(LTC[0], LTC[1], LTC[0]+ISO_DX, LTC[1]-ISO_DY, C.dim, 1, '5,3'),
  txt(LTC[0]+ISO_DX/2+8, LTC[1]-ISO_DY/2-12, '230 (prof.)', 10, 'middle', C.dim),
].join('\n');

// 5. Descarga — cota
const dimDischarge = arrow(discharge_front[0][0], discharge_front[0][1],
                           discharge_front[1][0], discharge_front[1][1], '80', 18, 1, 10);

// 6. Espessura da chapa
const thickLabel = txt(LF[1][0]-30, LF[1][1]-20, 'e = 2,5mm', 9, 'middle', C.dim, 'normal', true);

// 7. Cota de altura total do V (do vertex até o topo dos flanges)
const htot = VY - LTC[1];  // approx in px
const dimHeight = [
  line(LTC[0]-70, LTC[1], LTC[0]-50, LTC[1], C.dim, 0.8),
  line(VX-70, VY, VX-50, VY, C.dim, 0.8),
  `<line x1="${r(LTC[0]-60)}" y1="${r(LTC[1])}" x2="${r(LTC[0]-60)}" y2="${r(VY)}" stroke="${C.dim}" stroke-width="1" marker-start="url(#markerArr)" marker-end="url(#markerArr)"/>`,
  txt(LTC[0]-60-14, (LTC[1]+VY)/2, '~460', 10, 'middle', C.dim),
].join('\n');

// Etiquetas de componentes
const labels = [
  // Flanges
  txt(LTC[0]-FLANGE_R-35, LTC[1]-20, 'Flange eixo', 9, 'middle', C.dim),
  txt(LTC[0]-FLANGE_R-35, LTC[1]-8,  'Ø150 | 8×M8', 9, 'middle', C.dim),
  // Tampas limpeza
  txt((L_cover[0][0]+L_cover[1][0])/2-22, (L_cover[0][1]+L_cover[1][1])/2-10, 'Tampa', 8, 'middle', C.dim),
  txt((L_cover[0][0]+L_cover[1][0])/2-22, (L_cover[0][1]+L_cover[1][1])/2+2, 'limpeza', 8, 'middle', C.dim),
  // Descarga
  txt(VX, discharge_front[2][1]+18, 'Saída Ø80', 9, 'middle', C.dim),
  // Material
  txt(600, H_SVG-30, 'Material: AISI 316L | Solda TIG + backing gas argônio | Ra int. ≤ 0,4 μm | Norma: ASTM A240 + EHEDG Cat.II + ANVISA RDC 49', 9, 'middle', '#888'),
  // Referência central
  txt(420, VY+50, 'V  =  90°', 11, 'middle', C.dim),
].join('\n');

// ============================================================================
//  VISTA EXPLODIDA DO EIXO
// ============================================================================
const exLabel  = txt(EX + (shaftEnd-EX)/2, 90, 'VISTA EXPLODIDA — CONJUNTO DE EIXO', 13, 'middle', C.title, 'bold');
const exLabel2 = txt(EX + (shaftEnd-EX)/2, 108, 'Tambor + Eixo ∅35mm + Rolamentos + Mancais (escala orientativa)', 10, 'middle', '#888');

// Linha-eixo horizontal (linha de centro)
const centerLine = line(SX-mm(20), EY, shaftEnd+mm(20), EY, '#999', 0.8, '10,5');

// ── EIXO ─────────────────────────────────────────────────────────────────────
const shaftRect = rect(SX-mm(20), EY-SHAFT_R, shaftEnd-SX+mm(40), SHAFT_R*2, C.shaft, '#5C4010', 2);

// ── MANCAL ESQUERDO ──────────────────────────────────────────────────────────
const manLRect  = rect(manL_x, EY-MAN_R, MAN_L, MAN_R*2, '#C8C8C8', C.line, 2, 4);
const manLHole  = circ(manL_x+MAN_L/2, EY, BRG_R+mm(4), '#A8A8A8', C.line, 1);
const manLLabel = [
  txt(manL_x+MAN_L/2, EY+MAN_R+22, 'Mancal', 10, 'middle', C.dim),
  txt(manL_x+MAN_L/2, EY+MAN_R+36, 'Flangeado Inox', 10, 'middle', C.dim),
  txt(manL_x+MAN_L/2, EY+MAN_R+50, '∅35mm | 304', 10, 'middle', C.dim),
].join('\n');

// ── ROLAMENTO ESQUERDO ────────────────────────────────────────────────────────
const brgL_cx = brgL_x + BRG_L/2;
const brgLOuter = rect(brgL_x, EY-BRG_R, BRG_L, BRG_R*2, C.brg, C.line, 2, 3);
const brgLInner = rect(brgL_x, EY-SHAFT_R-mm(5), BRG_L, (SHAFT_R+mm(5))*2, '#5577CC', C.line, 1, 2);
const brgLLabel = [
  txt(brgL_cx, EY-BRG_R-12, 'Rolamento', 10, 'middle', C.dim),
  txt(brgL_cx, EY-BRG_R-0,  'SKF 6307-2RS1', 10, 'middle', C.dim),
  txt(brgL_cx, EY-BRG_R+12, '∅35 × ∅80 | 2RS', 10, 'middle', C.dim),
].join('\n');

// ── TAMBOR (representação simplificada) ──────────────────────────────────────
const drum_cx   = drum_x + DRUM_W/2;
const drum_h    = mm(280); // altura visual do tambor na explodida
const drumVBody = [
  // Face simplificada do tambor — losango/V
  poly([
    [drum_cx, EY-drum_h/2],    // topo
    [drum_cx+DRUM_W/2, EY],    // dir
    [drum_cx, EY+drum_h*0.3],  // base (vertex)
    [drum_cx-DRUM_W/2, EY],    // esq
  ], C.body, C.line, 2),
  // Flange esq. do tambor
  rect(drum_x, EY-mm(30), mm(15), mm(60), '#C2C2C2', C.line, 1.5, 2),
  // Flange dir. do tambor
  rect(drum_x+DRUM_W-mm(15), EY-mm(30), mm(15), mm(60), '#C2C2C2', C.line, 1.5, 2),
  // Furo do eixo
  circ(drum_x+mm(7), EY, SHAFT_R+mm(1), '#888', C.line, 1),
  circ(drum_x+DRUM_W-mm(7), EY, SHAFT_R+mm(1), '#888', C.line, 1),
  // Label
  txt(drum_cx, EY-drum_h/2-18, 'TAMBOR EM V', 11, 'middle', C.line, 'bold'),
  txt(drum_cx, EY-drum_h/2-6,  'AISI 316L | ~74 L | 15–20 kg', 10, 'middle', C.dim),
].join('\n');

// Chaveta
const chaveta = [
  rect(drum_cx+SHAFT_R, EY-mm(4), mm(50), mm(8), '#AA8830', C.line, 1, 1),
  txt(drum_cx+SHAFT_R+mm(25), EY-mm(4)-8, 'Chaveta 10×8×50 A4', 9, 'middle', C.dim),
].join('\n');

// ── ROLAMENTO DIREITO ─────────────────────────────────────────────────────────
const brgR_cx = brgR_x + BRG_L/2;
const brgROuter = rect(brgR_x, EY-BRG_R, BRG_L, BRG_R*2, C.brg, C.line, 2, 3);
const brgRInner = rect(brgR_x, EY-SHAFT_R-mm(5), BRG_L, (SHAFT_R+mm(5))*2, '#5577CC', C.line, 1, 2);
const brgRLabel = [
  txt(brgR_cx, EY-BRG_R-12, 'Rolamento', 10, 'middle', C.dim),
  txt(brgR_cx, EY-BRG_R-0,  'SKF 6307-2RS1', 10, 'middle', C.dim),
  txt(brgR_cx, EY-BRG_R+12, '∅35 × ∅80 | 2RS', 10, 'middle', C.dim),
].join('\n');

// ── MANCAL DIREITO ────────────────────────────────────────────────────────────
const manRRect  = rect(manR_x, EY-MAN_R, MAN_L, MAN_R*2, '#C8C8C8', C.line, 2, 4);
const manRHole  = circ(manR_x+MAN_L/2, EY, BRG_R+mm(4), '#A8A8A8', C.line, 1);
const manRLabel = [
  txt(manR_x+MAN_L/2, EY+MAN_R+22, 'Mancal', 10, 'middle', C.dim),
  txt(manR_x+MAN_L/2, EY+MAN_R+36, 'Flangeado Inox', 10, 'middle', C.dim),
  txt(manR_x+MAN_L/2, EY+MAN_R+50, '∅35mm | 304', 10, 'middle', C.dim),
].join('\n');

// ── Linhas de centro / alinhamento ───────────────────────────────────────────
const alignLines = [
  line(manL_x+MAN_L, EY, brgL_x, EY, '#BBB', 0.8, '6,4'),
  line(brgL_x+BRG_L, EY, drum_x, EY, '#BBB', 0.8, '6,4'),
  line(drum_x+DRUM_W, EY, brgR_x, EY, '#BBB', 0.8, '6,4'),
  line(brgR_x+BRG_L, EY, manR_x, EY, '#BBB', 0.8, '6,4'),
].join('\n');

// ── Cota do eixo total ────────────────────────────────────────────────────────
const dimShaft = [
  line(SX-mm(20), EY+MAN_R+70, SX-mm(20), EY+MAN_R+55, C.dim, 0.8),
  line(shaftEnd+mm(20), EY+MAN_R+70, shaftEnd+mm(20), EY+MAN_R+55, C.dim, 0.8),
  `<line x1="${r(SX-mm(20))}" y1="${r(EY+MAN_R+62)}" x2="${r(shaftEnd+mm(20))}" y2="${r(EY+MAN_R+62)}" stroke="${C.dim}" stroke-width="1" marker-start="url(#markerArr)" marker-end="url(#markerArr)"/>`,
  txt((SX-mm(20)+shaftEnd+mm(20))/2, EY+MAN_R+78, 'Comprimento total do eixo: ~808mm  |  ∅35mm AISI 1045 beneficiado', 10, 'middle', C.dim),
].join('\n');

// ── Cota entre apoios (entre mancais) ────────────────────────────────────────
const dimBetween = [
  `<line x1="${r(manL_x+MAN_L/2)}" y1="${r(EY-MAN_R-22)}" x2="${r(manR_x+MAN_L/2)}" y2="${r(EY-MAN_R-22)}" stroke="${C.dim}" stroke-width="1" marker-start="url(#markerArr)" marker-end="url(#markerArr)"/>`,
  txt((manL_x+MAN_L/2+manR_x+MAN_L/2)/2, EY-MAN_R-32, 'Entre apoios: ~608mm', 10, 'middle', C.dim),
].join('\n');

// ── Legenda de cores ──────────────────────────────────────────────────────────
const legendX = EX, legendY = EY + MAN_R + 100;
const legend = [
  rect(legendX, legendY, 14, 14, C.shaft, C.line, 1),
  txt(legendX+20, legendY+11, 'Eixo AISI 1045', 10, 'start', C.dim),
  rect(legendX+160, legendY, 14, 14, C.brg, C.line, 1),
  txt(legendX+180, legendY+11, 'Rolamento SKF 6307', 10, 'start', C.dim),
  rect(legendX+370, legendY, 14, 14, '#C8C8C8', C.line, 1),
  txt(legendX+390, legendY+11, 'Mancal inox 304', 10, 'start', C.dim),
  rect(legendX+550, legendY, 14, 14, C.body, C.line, 1),
  txt(legendX+570, legendY+11, 'Tambor AISI 316L', 10, 'start', C.dim),
  rect(legendX+730, legendY, 14, 14, '#AA8830', C.line, 1),
  txt(legendX+750, legendY+11, 'Chaveta 10×8×50 A4', 10, 'start', C.dim),
].join('\n');

// ── Rodapé ────────────────────────────────────────────────────────────────────
const footer = [
  line(0, H_SVG-40, W_SVG, H_SVG-40, '#CCC', 0.5),
  rect(0, H_SVG-40, W_SVG, 40, '#F0F0F0', 'none'),
  txt(40, H_SVG-22, 'Doc: PF-TAMBOR-V-001  Rev.A  |  2026-06-11', 9, 'start', '#888'),
  txt(W_SVG/2, H_SVG-22, 'Misturador em V Alimentício — Tambor AISI 316L — Projeto Técnico', 9, 'middle', '#888'),
  txt(W_SVG-40, H_SVG-22, 'TODOS OS DIREITOS RESERVADOS', 9, 'end', '#AAA'),
].join('\n');

// ── Montagem final ────────────────────────────────────────────────────────────
const svgContent = `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${W_SVG}" height="${H_SVG}" viewBox="0 0 ${W_SVG} ${H_SVG}"
     xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
${defs}
${bg}
${titleBar}
${divLine}

<!-- ═══ VISTA PRINCIPAL ═══ -->
<g id="main-view">
${mainViewLabel}
${views}
${dimArmWidth}
${dimArmLen}
${angLabel}
${angArc}
${depthLine}
${dimDischarge}
${thickLabel}
${dimHeight}
${labels}
</g>

<!-- ═══ VISTA EXPLODIDA ═══ -->
<g id="exploded-view">
${exLabel}
${exLabel2}
${centerLine}
${shaftRect}
${alignLines}
${manLRect}${manLHole}${manLLabel}
${brgLOuter}${brgLInner}${brgLLabel}
${drumVBody}
${chaveta}
${brgROuter}${brgRInner}${brgRLabel}
${manRRect}${manRHole}${manRLabel}
${dimShaft}
${dimBetween}
${legend}
</g>

${footer}
</svg>`;

fs.writeFileSync(OUT, svgContent);
console.log('SVG gerado:', OUT);
console.log('Abrir no navegador: file:///' + OUT.replace(/\\/g,'/'));
