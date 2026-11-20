<script setup>
import DadoTallado from './DadoTallado.vue'
import { materiales } from '../../utils/poliedros.js'

const props = defineProps({
  titulo: String, pool: { type: Array, required: true }, tirada: Object, tirando: Boolean
})
const bono = defineModel('bono')
const emit = defineEmits(['agregar','quitar','limpiar','tirar','repetir'])
const carasDisponibles = [4,6,8,10,12,20,100]
const grupos = computed(() => {
  const cantidades = new Map()
  for (const c of props.pool) cantidades.set(c,(cantidades.get(c) || 0)+1)
  return Array.from(cantidades, ([caras,cantidad]) => ({ caras,cantidad }))
})
const dados = computed(() => props.tirada?.dados || [])
const natural = d => d.caras === 20 && (d.valor === 20 || d.valor === 1)
const desglose = computed(() => {
  const t = props.tirada
  if (!t || props.tirando) return ''
  const suma = t.total - t.bono
  if (t.bono) return suma + (t.bono > 0 ? ' + ' : ' − ') + Math.abs(t.bono)
  return t.dados.length > 1 ? t.dados.length + ' dados' : ''
})
const decenas = n => String(Math.floor((n % 100) / 10) * 10).padStart(2,'0')
</script>

<template>
  <section class="lanzador" :aria-label="titulo">
    <header class="cabecera">
      <h2>{{ titulo }}</h2>
      <div class="lectura" role="status" aria-live="polite" aria-atomic="true">
        <span>{{ tirando ? 'Rodando' : 'Total' }}<small v-if="desglose">{{ desglose }}</small></span>
        <strong class="total" :key="tirada?.id + '-' + tirando" :class="{ revelar: tirada && !tirando }">
          {{ tirando || !tirada ? '—' : tirada.total }}
        </strong>
      </div>
    </header>
    <div class="marco">
      <div class="bandeja" :class="{'muchos': dados.length > 6}" aria-label="Dados de la última tirada">
        <div v-if="!tirada" class="espera">
          <DadoTallado :caras="20" />
          <p>Elegí los dados y pulsá Tirar.</p>
        </div>
        <figure v-for="(d,i) in dados" :key="tirada.id + '-' + i" class="pieza"
          :class="{ natural: !tirando && natural(d) }"
          :aria-label="tirando ? 'Dado en movimiento' : 'd' + d.caras + ': ' + d.valor">
          <span v-if="i >= 16" class="compacto">{{ tirando ? '·' : d.valor }}</span>
          <div v-else-if="d.caras === 100" class="par">
            <DadoTallado v-for="(v,j) in [decenas(d.valor), d.valor % 10]" :key="j" :caras="10" :valor="v"
              :inicio="tirada.inicio" :duracion="tirada.duracion" :orden="i+j" percentil />
          </div>
          <DadoTallado v-else :caras="d.caras" :valor="d.valor" :marcado="natural(d)"
            :inicio="tirada.inicio" :duracion="tirada.duracion" :orden="i" />
          <figcaption>
            {{ !tirando && natural(d) ? d.valor + ' natural' : 'd' + d.caras }}
            <b v-if="!tirando && d.caras === 100"> · {{ d.valor }}</b>
          </figcaption>
        </figure>
      </div>
    </div>
    <div class="controles">
      <div class="selector" role="group" aria-label="Agregar dados">
        <button v-for="caras in carasDisponibles" :key="caras" type="button"
          :style="{ '--matiz': materiales[caras] }" :aria-label="'Agregar d' + caras"
          :disabled="tirando" @click="emit('agregar',caras)">d{{ caras }}</button>
      </div>
      <div v-if="grupos.length" class="seleccion" aria-label="Selección de dados">
        <button v-for="g in grupos" :key="g.caras" type="button" :aria-label="'Quitar un d' + g.caras"
          :disabled="tirando" @click="emit('quitar',g.caras)">{{ g.cantidad }}d{{ g.caras }} <span>−</span></button>
      </div>
      <div class="orden">
        <label>Bono <input type="number" v-model.number="bono" :disabled="tirando" /></label>
        <button type="button" :disabled="tirando || (!pool.length && !bono && !tirada)" @click="emit('limpiar')">Limpiar</button>
        <button class="lanzar" type="button" :disabled="tirando || !pool.length" @click="emit('tirar')">Tirar</button>
      </div>
      <footer v-if="tirada && !tirando" class="ultima">
        <span>{{ tirada.titulo }}</span>
        <button type="button" @click="emit('repetir')">Repetir tirada</button>
      </footer>
    </div>
  </section>
</template>

<style scoped>
.lanzador { min-width: 0; color: #efeae2; background: #141317; font-family: Inter, sans-serif; }
.cabecera, .lectura, .orden, .orden label, .ultima { display: flex; align-items: center; }
.cabecera { min-height: 4.4rem; justify-content: space-between; gap: .8rem; padding: .65rem 1rem; background: linear-gradient(105deg,#211e22,#161419); }
h2 { margin: 0; font: 600 1.2rem/1.25 Cinzel, Georgia, serif; color: #f6e5c3; }
.lectura { flex-shrink: 0; gap: .65rem; text-align: right; }
.lectura > span { color: #cebc9e; font-size: .85rem; }
.lectura small { display: block; color: #c3bbc6; font-variant-numeric: tabular-nums; }
.total { min-width: 1.6ch; font: 600 2.1rem/1 Georgia,serif; color: #ffe0a2; text-align: center; }
.revelar { animation: revelar .36s ease-out; }
.marco { padding: .42rem; border-block: 1px solid #68543f; background: linear-gradient(155deg,#47362e,#211b1c 45%,#49362a); }
.bandeja { display: flex; justify-content: center; align-content: safe center; align-items: center; flex-wrap: wrap; min-height: 10.25rem; max-height: 18rem; overflow-y: auto; gap: .55rem; padding: .7rem .5rem; border: 1px solid #63555e; border-radius: 8px; box-shadow: inset 0 2px 18px #080712bb;
  background: repeating-linear-gradient(35deg,transparent 0 3px,#ffffff04 3px 4px),radial-gradient(ellipse at 50% 10%,#353149,#1f1d30 63%,#141321); }
.espera { display: grid; justify-items: center; --lado-dado: 4.9rem; }
.espera .talla { opacity: .77; }
.espera p { font-size: .88rem; color: #d3cbd9; margin: 0; }
.pieza { display: grid; place-items: center; margin: 0; min-width: 0; }
.pieza figcaption { color: #e5d9c5; letter-spacing: .03em; font: 600 .78rem/1.35 Inter,sans-serif; }
.natural figcaption { color: #ffe09a; }
.natural .talla { filter: drop-shadow(0 0 5px #d9a84a80); }
.compacto { display: grid; place-items: center; margin: .35rem; min-width: 2.55rem; height: 2.55rem; border: 1px solid #86779d; border-radius: 8px; background: #322b45; color: #fcf1d8; font: bold 1.15rem Georgia,serif; }
.par { display: flex; align-items: center; gap: 0; --lado-dado: 4.7rem; }
.muchos { --lado-dado: 4.1rem; }
.muchos .par { --lado-dado: 3.4rem; }
.controles { display: grid; gap: .7rem; padding: .85rem 1rem; }
.selector { display: grid; grid-template-columns: repeat(auto-fit,minmax(2.62rem,1fr)); gap: .3rem; }
button, input { font: inherit; }
.selector button, .orden button, .orden input, .seleccion button { color: #f1e6d3; background: #211e24; border: 1px solid #4e4549; border-radius: 6px; }
.selector button { background: linear-gradient(0deg,hsl(var(--matiz) 23% 17%),#211e24 78%); box-shadow: inset 0 -2px hsl(var(--matiz) 43% 58%); font-weight: 600; font-size: .87rem; }
.selector button, .orden button, .orden input { min-height: 44px; }
button { cursor: pointer; transition: background-color .15s, transform .15s, border-color .15s; }
button:hover:enabled { border-color: #bc9a6c; }
button:active:enabled { transform: translateY(1px); }
button:disabled { opacity: .52; cursor: default; }
.seleccion, .orden { display: flex; gap: .45rem; flex-wrap: wrap; }
.seleccion button { min-height: 2rem; padding: .15rem .55rem; font-size: .8rem; }
.seleccion span { color: #d2b47b; }
.orden label { gap: .45rem; margin-right: auto; font-size: .9rem; }
.orden input { width: 3.4rem; text-align: center; }
.orden button { padding: .3rem .8rem; }
.orden .lanzar { background: linear-gradient(#f8d69c,#d9ac68); color: #2b2014; border-color: #c99c5a; font-weight: 700; min-width: 4rem; }
.ultima { justify-content: space-between; gap: .65rem; border-top: 1px solid #383137; padding-top: .4rem; font-size: .8rem; color: #bdb4be; }
.ultima span { overflow-wrap: anywhere; }
.ultima button { color: #eed09a; text-decoration: underline; text-underline-offset: .18em; min-height: 2.2rem; white-space: nowrap; }
@keyframes revelar { from { opacity: .35; transform: translateY(.25rem) scale(.88); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { *, *::before { animation: none !important; transition: none !important; } }
</style>
