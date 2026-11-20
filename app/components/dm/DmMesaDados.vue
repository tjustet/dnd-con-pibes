<script setup>
const props = defineProps({
  historialCompartido: Array,
  todasLasEntidadesActivas: Array,
  dmDadosEnMesa: Array,
  dmTirando: Boolean,
  dmResultadoFinal: Number,
  dmPool: Array
})

const carasDisponibles = [4, 6, 8, 10, 12, 20, 100]
const grupos = computed(() => carasDisponibles.map(caras => ({
  caras, cantidad: props.dmPool.filter(d => d === caras).length
})).filter(grupo => grupo.cantidad))

const dmBono = defineModel('dmBono')

const emit = defineEmits([
  'limpiar-historial', 'aplicar-dano', 'curar-dano', 'aplicar-efecto',
  'agregar-dado', 'quitar-dado', 'limpiar-pool', 'tirar-pool'
])
</script>

<template>
  <div class="centro-dados-dm">
    <section class="estacion" aria-label="Mesa de dados">
      <div class="lanzador">
        <header class="cabecera">
          <h2>Mesa de dados</h2>
          <p role="status" class="total-tirada">{{ dmTirando ? 'Tirando…' : 'Total' }}
            <strong v-if="!dmTirando">{{ dmDadosEnMesa.length ? dmResultadoFinal : '—' }}</strong>
          </p>
        </header>
        <div class="bandeja" aria-label="Dados de la última tirada">
          <p v-if="!dmDadosEnMesa.length">Elegí los dados y pulsá Tirar.</p>
          <div v-for="(d, i) in dmDadosEnMesa" :key="i" class="pieza" :class="{ rodando: dmTirando }">
            <span class="cara" :class="'caras-' + d.caras">{{ d.valor }}</span>
            <small>d{{ d.caras }}</small>
          </div>
        </div>
        <div class="configuracion">
          <div class="selector" role="group" aria-label="Agregar dados">
            <button v-for="caras in carasDisponibles" :key="caras" type="button"
              :aria-label="'Agregar d' + caras" :disabled="dmTirando" @click="emit('agregar-dado', caras)">d{{ caras }}</button>
          </div>
          <div v-if="grupos.length" class="seleccion" aria-label="Selección de dados">
            <button v-for="g in grupos" :key="g.caras" type="button" :disabled="dmTirando"
              :aria-label="'Quitar un d' + g.caras" @click="emit('quitar-dado', g.caras)">{{ g.cantidad }}d{{ g.caras }} −</button>
          </div>
          <div class="orden">
            <label>Bono <input type="number" v-model.number="dmBono" :disabled="dmTirando" /></label>
            <button type="button" :disabled="dmTirando || (!dmPool.length && !dmBono)" @click="emit('limpiar-pool')">Limpiar</button>
            <button type="button" class="lanzar" :disabled="dmTirando || !dmPool.length" @click="emit('tirar-pool', null)">Tirar</button>
          </div>
        </div>
      </div>
      <aside class="registro">
        <div class="cabecera-registro">
          <h3>Historial de tiradas</h3>
          <button type="button" :disabled="!historialCompartido.length" @click="emit('limpiar-historial')">Borrar</button>
        </div>
        <div class="historial-dm-scroll">
          <p v-if="!historialCompartido.length">Todavía no hay tiradas.</p>
          <div v-for="h in historialCompartido" :key="h.id" class="hist-item-dm" :class="{'oculto-bg': h.oculto}">
            <div class="h-header">
              <span class="h-tirador" :class="{'t-dorado': h.tirador === 'DM'}">{{ h.tirador }}</span>
              <span v-if="h.oculto" class="ojo-oculto">👁️‍🗨️</span>
            </div>
            <div class="h-tit">{{ h.titulo }}</div>
            <div class="h-datos">{{ h.dadosStr }}</div>
            <div class="h-body-row">
              <div class="h-bono">Bono: {{ h.bono >= 0 ? '+' : '' }}{{ h.bono }}</div>
              <div class="h-total">{{ h.total }}</div>
            </div>
            
            <button class="btn-toggle-dano" @click="h.mostrarAsignador = !h.mostrarAsignador">🎯 Asignar...</button>
            <div v-if="h.mostrarAsignador" class="asignador-box">
              <select v-model="h.targetAsignado" class="select-target">
                <option value="">Blanco...</option>
                <option v-for="ent in todasLasEntidadesActivas" :key="ent.instance_id || ent.id" :value="ent.instance_id || ent.id">{{ ent.nombre_pj }}</option>
              </select>
              <div class="asignador-acciones" v-if="h.targetAsignado">
                <button class="btn-asig dmg" @click="emit('aplicar-dano', h)">Daño</button>
                <button class="btn-asig heal" @click="emit('curar-dano', h)">Cura</button>
                <button v-if="h.efecto_vinculado" class="btn-asig veneno" @click="emit('aplicar-efecto', h)" :title="h.efecto_vinculado.descripcion">{{ h.efecto_vinculado.icono }} Estado</button>
              </div>
            </div>
          </div>
        </div>
      </aside>
    </section>
  </div>
</template>

<style scoped>
.centro-dados-dm { display: block; height: auto; min-width: 0; container-type: inline-size; }
.estacion { display: grid; grid-template-columns: minmax(0, 1fr) minmax(12rem, 31%); background: #101113; border: 1px solid #4e4434; border-radius: 12px; overflow: hidden; color: #eee9e0; }
.lanzador, .registro { min-width: 0; }
.cabecera, .cabecera-registro, .orden, .orden label { display: flex; align-items: center; gap: .6rem; }
.cabecera, .cabecera-registro { justify-content: space-between; }
.cabecera, .configuracion, .registro { padding: .9rem; }
h2, h3 { font-family: Cinzel, Georgia, serif; margin: 0; }
h2 { font-size: 1.2rem; } h3 { font-size: .95rem; }
.total-tirada { margin: 0; display: flex; align-items: baseline; gap: .5rem; color: #cbbd9d; }
.total-tirada strong { color: #ffdc8e; font-size: 1.6rem; font-variant-numeric: tabular-nums; }
.bandeja { display: flex; flex-wrap: wrap; justify-content: center; align-items: center; align-content: safe center; gap: .85rem; min-height: 9rem; max-height: 16rem; overflow: auto; padding: 1.1rem; background: radial-gradient(ellipse at 50% 15%,#223c35,#101c1b); border-block: 1px solid #3d4a40; }
.bandeja p, .historial-dm-scroll > p { font-size: .87rem; color: #c2cdc7; }
.pieza { display: grid; justify-items: center; gap: .2rem; }
.pieza small { font: 600 .75rem/1.4 Inter,sans-serif; color: #dfd6c1; }
.cara { display: grid; place-items: center; width: 3.6rem; height: 3.6rem; font: 700 1.3rem/1 Inter,sans-serif; font-variant-numeric: tabular-nums; color: #fff5d9; text-shadow: 0 1px 3px #000; background: conic-gradient(from 30deg at 50% 68%,#85683e,#55402c 33%,#a2814e 34%,#59472f 66%,#a48654 67%,#85683e); clip-path: polygon(25% 3%,75% 3%,99% 50%,75% 97%,25% 97%,1% 50%); }
.caras-4 { clip-path: polygon(50% 1%,99% 95%,1% 95%); padding-top: .95rem; }
.caras-6 { clip-path: none; border-radius: .6rem; border: 1px solid #ac8d5b; }
.caras-8 { clip-path: polygon(50% 0,100% 50%,50% 100%,0 50%); }
.caras-10, .caras-100 { clip-path: polygon(50% 0,94% 29%,91% 70%,50% 100%,9% 70%,6% 29%); }
.caras-12 { clip-path: polygon(50% 0,98% 34%,80% 94%,20% 94%,2% 34%); }
.caras-20 { background-color: #555d93; background-blend-mode: luminosity; }
.rodando .cara { animation: vibrar .23s ease-in-out infinite alternate; }
@keyframes vibrar { from { transform: rotate(-7deg); } to { transform: rotate(7deg); } }
.configuracion { display: grid; gap: .75rem; }
.selector { display: grid; grid-template-columns: repeat(auto-fit,minmax(2.7rem,1fr)); gap: .3rem; }
.selector button, .orden button, .orden input, .seleccion button, .cabecera-registro button { border: 1px solid #46413a; border-radius: 6px; background: #1b1a19; color: #f4e8cf; }
.selector button, .orden button, .orden input { min-height: 44px; }
.seleccion { display: flex; flex-wrap: wrap; gap: .4rem; }
.seleccion button, .cabecera-registro button { padding: .35rem .55rem; font-size: .83rem; }
.orden { flex-wrap: wrap; }
.orden label { margin-right: auto; font-size: .9rem; }
.orden input { width: 3.3rem; text-align: center; }
.orden button { padding-inline: .85rem; }
.orden .lanzar { background: #e9be70; color: #271b0d; font-weight: 700; }
.registro { border-left: 1px solid #373530; display: grid; grid-template-rows: auto minmax(0,1fr); gap: .7rem; background: #101014; }
.historial-dm-scroll { height: auto; max-height: 24rem; min-height: 0; }
@media (prefers-reduced-motion: reduce) {
  .rodando .cara { animation: none; }
}
@container (max-width: 39rem) {
  .estacion { grid-template-columns: minmax(0,1fr); }
  .registro { border-left: 0; border-top: 1px solid #373530; }
  .historial-dm-scroll { max-height: 11rem; }
}
</style>
