<script setup>
import { ref, computed } from 'vue'
const props = defineProps({ pj: Object, modoEdicion: Boolean })

const filtroInventario = ref('')
const inventarioFiltrado = computed(() => {
  if (!filtroInventario.value) return props.pj.inventario
  const f = filtroInventario.value.toLowerCase()
  return props.pj.inventario.filter(i => i.nombre.toLowerCase().includes(f) || i.nota.toLowerCase().includes(f))
})

const agregarItem = () => props.pj.inventario.push({ nombre: '', cant: 1, peso: '', nota: '', equipado: false })
const borrarItem = (index) => props.pj.inventario.splice(index, 1)
</script>

<template>
  <div class="panel-oscuro flex-col" style="padding-right: 0;">
    <div style="display: flex; gap: 1rem; height: 100%;">
      <div class="seccion-monedas-vertical">
        <div class="moneda pc"><label>PC</label><input v-if="modoEdicion" type="number" v-model="pj.monedas_cobre"/><span v-else>{{ pj.monedas_cobre }}</span></div>
        <div class="moneda pp"><label>PP</label><input v-if="modoEdicion" type="number" v-model="pj.monedas_plata"/><span v-else>{{ pj.monedas_plata }}</span></div>
        <div class="moneda po"><label>PO</label><input v-if="modoEdicion" type="number" v-model="pj.monedas_oro"/><span v-else>{{ pj.monedas_oro }}</span></div>
        <div class="moneda ppt"><label>PPT</label><input v-if="modoEdicion" type="number" v-model="pj.monedas_platino"/><span v-else>{{ pj.monedas_platino }}</span></div>
      </div>
      <div class="seccion-inventario-wrap flex-col">
        <div class="header-seccion-busqueda" style="padding-right: 1.2rem;">
          <h3 class="titulo-dorado">{{ pj.tipo === 'pj' ? 'INVENTARIO' : 'BOTÍN Y OBJETOS' }}</h3>
          <div class="contenedor-filtro"><input v-model="filtroInventario" placeholder="Buscar..." class="input-buscar-interno" /></div>
          <button v-if="modoEdicion" @click="agregarItem" class="btn-add">+ Añadir</button>
        </div>
        <div class="lista-inventario">
          <div v-for="(item, idx) in inventarioFiltrado" :key="idx" class="item-inv relativo" :class="{'equipado': item.equipado}">
            <button v-if="modoEdicion" @click="borrarItem(idx)" class="btn-borrar-absoluto">Borrar</button>
            <div class="inv-fila-nom pr-borrar">
              <div class="inv-box flex-grow"><label>NOMBRE</label><input v-if="modoEdicion" v-model="item.nombre"/><span v-else class="texto-bold">{{ item.nombre || '-' }}</span></div>
              <div class="check-equipado"><input type="checkbox" v-model="item.equipado" :disabled="!modoEdicion" /><label>Equip.</label></div>
            </div>
            <div class="inv-fila-stats">
              <div class="inv-box cant"><label>CANT.</label><input v-if="modoEdicion" type="number" v-model="item.cant"/><span v-else class="texto-dorado">{{ item.cant }}x</span></div>
              <div class="inv-box peso"><label>PESO</label><input v-if="modoEdicion" v-model="item.peso"/><span v-else>{{ item.peso || '-' }}</span></div>
            </div>
            <div class="inv-fila-nota">
              <div class="inv-box w-full"><label>NOTA</label><textarea v-if="modoEdicion" v-model="item.nota" rows="2"></textarea><span v-else class="texto-gris">{{ item.nota || '-' }}</span></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>