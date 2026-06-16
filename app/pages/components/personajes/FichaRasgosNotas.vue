<script setup>
const props = defineProps({ pj: Object, modoEdicion: Boolean })
const agregarNota = () => props.pj.notas_array.push({ titulo: 'Nueva Nota', texto: '' })
const borrarNota = (index) => props.pj.notas_array.splice(index, 1)
</script>

<template>
  <div class="panel-oscuro flex-col">
    <div class="header-seccion"><h3 class="titulo-dorado">RASGOS FÍSICOS</h3></div>
    <div class="grilla-fisica mb-4">
      <div class="tag-fisico"><label>EDAD</label><input v-if="modoEdicion" v-model="pj.edad"/><span v-else>{{ pj.edad || '-' }}</span></div>
      <div class="tag-fisico"><label>ALTURA</label><input v-if="modoEdicion" v-model="pj.altura"/><span v-else>{{ pj.altura || '-' }}</span></div>
      <div class="tag-fisico"><label>PESO</label><input v-if="modoEdicion" v-model="pj.peso"/><span v-else>{{ pj.peso || '-' }}</span></div>
      <div class="tag-fisico"><label>OJOS</label><input v-if="modoEdicion" v-model="pj.ojos"/><span v-else>{{ pj.ojos || '-' }}</span></div>
      <div class="tag-fisico"><label>PIEL</label><input v-if="modoEdicion" v-model="pj.piel"/><span v-else>{{ pj.piel || '-' }}</span></div>
      <div class="tag-fisico"><label>PELO</label><input v-if="modoEdicion" v-model="pj.pelo"/><span v-else>{{ pj.pelo || '-' }}</span></div>
      
      <div v-if="pj.tipo !== 'pj'" class="tag-fisico w-full" style="grid-column: span 3;"><label>DIFICULTAD (CR)</label><input v-if="modoEdicion" v-model="pj.dificultad"/><span v-else>{{ pj.dificultad || '-' }}</span></div>
      <div v-if="pj.tipo !== 'pj'" class="tag-fisico w-full" style="grid-column: span 3;"><label>VULNERABILIDADES</label><input v-if="modoEdicion" v-model="pj.vulnerabilidades"/><span v-else>{{ pj.vulnerabilidades || '-' }}</span></div>
      <div v-if="pj.tipo !== 'pj'" class="tag-fisico w-full" style="grid-column: span 3;"><label>INMUNIDADES</label><input v-if="modoEdicion" v-model="pj.inmunidades"/><span v-else>{{ pj.inmunidades || '-' }}</span></div>
    </div>

    <div class="header-seccion">
      <h3 class="titulo-dorado">NOTAS Y REGISTROS</h3>
      <button v-if="modoEdicion" @click="agregarNota" class="btn-add">+ Añadir Nota</button>
    </div>
    <div class="lista-notas">
      <div v-for="(nota, idx) in pj.notas_array" :key="idx" class="bloque-nota relativo">
        <button v-if="modoEdicion" @click="borrarNota(idx)" class="btn-borrar-absoluto">Borrar</button>
        <div class="nota-header pr-borrar">
          <input v-if="modoEdicion" v-model="nota.titulo" class="input-nota-tit" placeholder="Título"/>
          <h4 v-else class="texto-nota-tit">{{ nota.titulo || 'Nota sin título' }}</h4>
        </div>
        <div class="nota-body">
          <textarea v-if="modoEdicion" v-model="nota.texto" rows="4"></textarea>
          <p v-else class="texto-wrap">{{ nota.texto || 'Vacío.' }}</p>
        </div>
      </div>
    </div>
  </div>
</template>