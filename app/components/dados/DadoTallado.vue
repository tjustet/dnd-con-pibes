<script setup>
import { pintarDado } from '../../utils/poliedros.js'

const props = defineProps({
  caras: Number, valor: [Number, String], orden: { type: Number, default: 0 },
  inicio: Number, duracion: { type: Number, default: 0 }, percentil: Boolean, marcado: Boolean
})
const lienzo = ref(null)
let cuadro
const disponible = ref(false)

function dibujar() {
  cancelAnimationFrame(cuadro)
  const canvas = lienzo.value
  const ctx = canvas?.getContext('2d')
  if (!ctx) return
  disponible.value = true
  const px = Math.round(100 * Math.min(window.devicePixelRatio || 1, 2))
  if (canvas.width !== px) { canvas.width = px; canvas.height = px }
  ctx.setTransform(px/100,0,0,px/100,0,0)
  function avanzar(ahora) {
    const progreso = props.duracion ? Math.min(1,Math.max(0,(ahora-props.inicio)/props.duracion)) : 1
    pintarDado(ctx, props.caras, props.valor, progreso, props.orden, props.marcado, props.percentil)
    if (progreso < 1) cuadro = requestAnimationFrame(avanzar)
  }
  avanzar(performance.now())
}
onMounted(dibujar)
watch(() => [props.caras,props.valor,props.inicio,props.duracion,props.marcado], dibujar, { flush: 'post' })
onBeforeUnmount(() => cancelAnimationFrame(cuadro))
</script>

<template>
  <span class="talla" aria-hidden="true">
    <canvas ref="lienzo" width="100" height="100"></canvas>
    <span v-if="!disponible" class="alternativa">{{ valor ?? '◇' }}</span>
  </span>
</template>

<style scoped>
.talla { display: inline-grid; place-items: center; width: var(--lado-dado,5.8rem); aspect-ratio: 1; }
.talla > * { grid-area: 1 / 1; }
canvas { display: block; width: 100%; height: 100%; }
.alternativa { font: bold 1.45rem Georgia,serif; color: #f7dfab; }
</style>
