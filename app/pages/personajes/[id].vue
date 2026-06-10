<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import MesaDados from '../components/MesaDados.vue'

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()

const cargando = ref(true)
const esNuevo = ref(route.params.id === 'nuevo')
const modoEdicion = ref(esNuevo.value)

const listaPerfiles = ref([])
const filtroAtaques = ref('')
const filtroInventario = ref('')

// Referencia a nuestro nuevo componente de dados
const mesaRef = ref(null)

const pj = ref({
  nombre_pj: '', raza: '', clase: '', nivel: 1, player_email: '', campaign_id: route.query.campana || null,
  imagen_url: '', alineamiento: '', xp: 0, 
  clase_armadura: 10, velocidad: 30, hp_max: 10, hp_actual: 10,
  salvaciones_exito: 0, salvaciones_fallo: 0,
  fuerza: 10, destreza: 10, constitucion: 10, inteligencia: 10, sabiduria: 10, carisma: 10,
  prof_fuerza_salv: false, prof_atletismo: false,
  prof_destreza_salv: false, prof_acrobacias: false, prof_juego_manos: false, prof_sigilo: false,
  prof_constitucion_salv: false,
  prof_inteligencia_salv: false, prof_arcano: false, prof_historia: false, prof_investigacion: false, prof_naturaleza: false, prof_religion: false,
  prof_sabiduria_salv: false, prof_medicina: false, prof_percepcion: false, prof_perspicacia: false, prof_supervivencia: false, prof_trato_animales: false,
  prof_carisma_salv: false, prof_engano: false, prof_intimidacion: false, prof_interpretacion: false, prof_persuasion: false,
  monedas_cobre: 0, monedas_plata: 0, monedas_oro: 0, monedas_platino: 0,
  inventario: [], ataques: [], notas_array: [], 
  edad: '', altura: '', peso: '', ojos: '', piel: '', pelo: ''
})

const caracteristicas = [
  { id: 'fuerza', nombre: 'FUERZA', habilidades: [{ id: 'prof_fuerza_salv', nombre: 'Salvación' }, { id: 'prof_atletismo', nombre: 'Atletismo' }] },
  { id: 'destreza', nombre: 'DESTREZA', habilidades: [{ id: 'prof_destreza_salv', nombre: 'Salvación' }, { id: 'prof_acrobacias', nombre: 'Acrobacias' }, { id: 'prof_juego_manos', nombre: 'Juegos de Manos' }, { id: 'prof_sigilo', nombre: 'Sigilo' }] },
  { id: 'constitucion', nombre: 'CONSTITUCIÓN', habilidades: [{ id: 'prof_constitucion_salv', nombre: 'Salvación' }] },
  { id: 'inteligencia', nombre: 'INTELIGENCIA', habilidades: [{ id: 'prof_inteligencia_salv', nombre: 'Salvación' }, { id: 'prof_arcano', nombre: 'C. Arcano' }, { id: 'prof_historia', nombre: 'Historia' }, { id: 'prof_investigacion', nombre: 'Investigación' }, { id: 'prof_naturaleza', nombre: 'Naturaleza' }, { id: 'prof_religion', nombre: 'Religión' }] },
  { id: 'sabiduria', nombre: 'SABIDURÍA', habilidades: [{ id: 'prof_sabiduria_salv', nombre: 'Salvación' }, { id: 'prof_medicina', nombre: 'Medicina' }, { id: 'prof_percepcion', nombre: 'Percepción' }, { id: 'prof_perspicacia', nombre: 'Perspicacia' }, { id: 'prof_supervivencia', nombre: 'Supervivencia' }, { id: 'prof_trato_animales', nombre: 'T. Animales' }] },
  { id: 'carisma', nombre: 'CARISMA', habilidades: [{ id: 'prof_carisma_salv', nombre: 'Salvación' }, { id: 'prof_engano', nombre: 'Engaño' }, { id: 'prof_intimidacion', nombre: 'Intimidación' }, { id: 'prof_interpretacion', nombre: 'Interpretación' }, { id: 'prof_persuasion', nombre: 'Persuasión' }] }
]

const ataquesFiltrados = computed(() => {
  if (!filtroAtaques.value) return pj.value.ataques
  const f = filtroAtaques.value.toLowerCase()
  return pj.value.ataques.filter(a => a.nombre.toLowerCase().includes(f) || a.desc.toLowerCase().includes(f))
})

const inventarioFiltrado = computed(() => {
  if (!filtroInventario.value) return pj.value.inventario
  const f = filtroInventario.value.toLowerCase()
  return pj.value.inventario.filter(i => i.nombre.toLowerCase().includes(f) || i.nota.toLowerCase().includes(f))
})

const calcMod = (valor) => Math.floor((valor - 10) / 2)
const calcModStr = (valor) => { const m = calcMod(valor); return m >= 0 ? `+${m}` : m }
const calcHabilidadNum = (statBase, isProf) => calcMod(pj.value[statBase]) + (isProf ? 3 : 0)
const calcHabilidadStr = (statBase, isProf) => {
  const total = calcHabilidadNum(statBase, isProf)
  return total >= 0 ? `+${total}` : total
}

const hpPorcentaje = computed(() => {
  if (pj.value.hp_max <= 0) return 0
  return Math.max(0, Math.min(100, (pj.value.hp_actual / pj.value.hp_max) * 100))
})

watch([() => pj.value.hp_actual, () => pj.value.hp_max], ([newActual, newMax]) => {
  if (newActual > newMax) pj.value.hp_actual = newMax
})

const reiniciarMuerte = () => {
  pj.value.salvaciones_exito = 0
  pj.value.salvaciones_fallo = 0
}

// ==========================================
// CANCELAR EDICIÓN
// ==========================================
const cancelarEdicion = () => {
  if (esNuevo.value) {
    router.back() // Si era nuevo y cancela, vuelve a la pantalla anterior
  } else {
    cargarFicha() // Recarga los datos desde la BD para borrar los cambios no guardados
    modoEdicion.value = false
  }
}

// ==========================================
// CONEXIÓN CON LA MESA DE DADOS (Componente Externo)
// ==========================================
const tirarAtaqueHit = (atk) => mesaRef.value?.tirar(`Ataque: ${atk.nombre}`, 1, 20, atk.bono)
const tirarAtaqueDano = (atk) => mesaRef.value?.tirar(`Daño: ${atk.nombre}`, atk.cant_dados || 1, atk.tipo_dado || 8, atk.bono_dano)
const tirarEstadistica = (nombre, statBase) => mesaRef.value?.tirar(`Prueba de ${nombre}`, 1, 20, calcMod(pj.value[statBase]))
const tirarHabilidad = (nombre, statBase, isProf) => mesaRef.value?.tirar(nombre, 1, 20, calcHabilidadNum(statBase, isProf))

const cargarFicha = async () => {
  const { data: perfilesData } = await supabase.from('profiles').select('email, nombre')
  if (perfilesData) listaPerfiles.value = perfilesData

  if (!esNuevo.value) {
    const { data } = await supabase.from('characters').select('*').eq('id', route.params.id).single()
    if (data) {
      if (!data.inventario) data.inventario = []
      if (!data.ataques) data.ataques = []
      let notasParseadas = []
      try { notasParseadas = data.notas ? JSON.parse(data.notas) : [] } catch { notasParseadas = [] }
      pj.value = { ...data, notas_array: notasParseadas }
    }
  } else {
    pj.value.player_email = route.query.email || ''
  }
  cargando.value = false
}

const guardarFicha = async () => {
  cargando.value = true
  try {
    const payload = { ...pj.value }
    payload.notas = JSON.stringify(payload.notas_array)
    delete payload.notas_array 

    let res;
    if (esNuevo.value) {
      res = await supabase.from('characters').insert([payload]).select()
      if (!res.error && res.data) {
        esNuevo.value = false
        router.replace(`/personajes/${res.data[0].id}`)
      }
    } else {
      res = await supabase.from('characters').update(payload).eq('id', payload.id)
    }
    
    if (res.error) throw res.error
    modoEdicion.value = false
  } catch (err) {
    alert("Error al forjar cambios.")
  } finally {
    cargando.value = false
  }
}

const agregarAtaque = () => pj.value.ataques.push({ nombre: '', bono: 0, cant_dados: 1, tipo_dado: 8, bono_dano: 0, rango: '', desc: '' })
const borrarAtaque = (index) => pj.value.ataques.splice(index, 1)
const agregarItem = () => pj.value.inventario.push({ nombre: '', cant: 1, peso: '', nota: '', equipado: false })
const borrarItem = (index) => pj.value.inventario.splice(index, 1)
const agregarNota = () => pj.value.notas_array.push({ titulo: 'Nueva Nota', texto: '' })
const borrarNota = (index) => pj.value.notas_array.splice(index, 1)

onMounted(() => { cargarFicha() })
</script>

<template>
  <div class="pantalla-ficha">
    <div class="filtro-oscuro"></div>

    <MesaDados ref="mesaRef" :jugador="pj.nombre_pj" />

    <div v-if="cargando" class="cargando">Abriendo grimorio...</div>
    
    <div v-else class="contenedor-principal">
      <div class="controles-superiores">
        <button @click="router.back()" class="btn-ghost">← Regresar</button>
        <div class="acciones-derecha">
          <button v-if="modoEdicion" @click="cancelarEdicion" class="btn-rojo">✖ Cancelar</button>
          
          <button v-if="!modoEdicion" @click="modoEdicion = true" class="btn-ghost">✏️ Editar Ficha</button>
          <button v-if="modoEdicion" @click="guardarFicha" class="btn-dorado">💾 Sellar Cambios</button>
        </div>
      </div>

      <div class="layout-maestro">
        
        <div class="panel-identidad">
          <div class="avatar-box">
            <img v-if="pj.imagen_url" :src="pj.imagen_url" class="avatar-img" />
            <div v-else class="avatar-placeholder">🛡️</div>
            <input v-if="modoEdicion" v-model="pj.imagen_url" placeholder="URL de la imagen" class="input-fino mt-1" />
          </div>

          <div class="datos-identidad">
            <div class="nombre-box">
              <input v-if="modoEdicion" v-model="pj.nombre_pj" placeholder="Nombre del Personaje" class="input-titulo" />
              <h1 v-else class="texto-titulo">{{ pj.nombre_pj || 'Héroe sin nombre' }}</h1>
            </div>
            
            <div class="tags-basicos">
              <div class="tag"><label>CLASE</label><input v-if="modoEdicion" v-model="pj.clase" class="input-base" /><span v-else>{{ pj.clase || '-' }}</span></div>
              <div class="tag"><label>NIVEL</label><input v-if="modoEdicion" type="number" v-model="pj.nivel" class="input-base" /><span v-else>{{ pj.nivel || 1 }}</span></div>
              <div class="tag"><label>RAZA</label><input v-if="modoEdicion" v-model="pj.raza" class="input-base" /><span v-else>{{ pj.raza || '-' }}</span></div>
              <div class="tag"><label>ALINEAMIENTO</label><input v-if="modoEdicion" v-model="pj.alineamiento" class="input-base" /><span v-else>{{ pj.alineamiento || '-' }}</span></div>
              <div class="tag"><label>XP</label><input v-if="modoEdicion" type="number" v-model="pj.xp" class="input-base" /><span v-else>{{ pj.xp || 0 }}</span></div>
              
              <div v-if="modoEdicion" class="tag selector-email-container">
                <label>VINCULAR JUGADOR (EMAIL)</label>
                <select v-model="pj.player_email" class="select-email-dark">
                  <option value="">-- Dejar sin asignar --</option>
                  <option v-for="prof in listaPerfiles" :key="prof.email" :value="prof.email">
                    {{ prof.nombre || 'Sin nombre' }} ({{ prof.email }})
                  </option>
                </select>
              </div>
            </div>
          </div>

          <div class="bloque-vitalidad">
            <div class="defensas">
              <div class="escudo-ca">
                <input v-if="modoEdicion" type="number" v-model="pj.clase_armadura" class="input-ca" />
                <span v-else>{{ pj.clase_armadura }}</span>
                <span class="lbl-escudo">CA</span>
              </div>
              <div class="box-chico">
                <label>VELOCIDAD</label>
                <div class="val-chico"><input v-if="modoEdicion" type="number" v-model="pj.velocidad" class="input-inline" /><span v-else>{{ pj.velocidad }}</span> ft</div>
              </div>
            </div>

            <div class="caja-hp">
              <div class="hp-header">
                <span class="lbl-dorado">VIDA</span>
                <span class="hp-max-text">MÁX: <input v-if="modoEdicion" type="number" v-model="pj.hp_max" class="input-inline" /><span v-else>{{ pj.hp_max }}</span></span>
              </div>
              <div class="hp-centro">
                <input v-if="modoEdicion" type="number" v-model="pj.hp_actual" class="input-hp-gigante" />
                <span v-else class="texto-hp-gigante">{{ pj.hp_actual }}</span>
              </div>
              <div class="barra-hp-fondo">
                <div class="barra-hp-relleno" :style="`width: ${hpPorcentaje}%`"></div>
                <span class="texto-porcentaje">{{ Math.round(hpPorcentaje) }}%</span>
              </div>
            </div>

            <div class="caja-muerte">
              <div class="header-muerte">
                <label>SALVACIONES DE MUERTE</label>
                <button v-if="modoEdicion" @click="reiniciarMuerte" class="btn-reinicio" title="Reiniciar">↻</button>
              </div>
              <div class="death-row">
                <span>ÉXITOS</span>
                <input type="checkbox" :checked="pj.salvaciones_exito >= 1" @change="pj.salvaciones_exito = $event.target.checked ? 1 : 0" :disabled="!modoEdicion">
                <input type="checkbox" :checked="pj.salvaciones_exito >= 2" @change="pj.salvaciones_exito = $event.target.checked ? 2 : pj.salvaciones_exito" :disabled="!modoEdicion">
                <input type="checkbox" :checked="pj.salvaciones_exito >= 3" @change="pj.salvaciones_exito = $event.target.checked ? 3 : pj.salvaciones_exito" :disabled="!modoEdicion">
              </div>
              <div class="death-row">
                <span>FALLOS</span>
                <input type="checkbox" :checked="pj.salvaciones_fallo >= 1" @change="pj.salvaciones_fallo = $event.target.checked ? 1 : 0" :disabled="!modoEdicion">
                <input type="checkbox" :checked="pj.salvaciones_fallo >= 2" @change="pj.salvaciones_fallo = $event.target.checked ? 2 : pj.salvaciones_fallo" :disabled="!modoEdicion">
                <input type="checkbox" :checked="pj.salvaciones_fallo >= 3" @change="pj.salvaciones_fallo = $event.target.checked ? 3 : pj.salvaciones_fallo" :disabled="!modoEdicion">
              </div>
            </div>
          </div>
        </div>

        <div class="grilla-estadisticas">
          <div v-for="car in caracteristicas" :key="car.id" class="caja-stat">
            <div class="stat-top">
              <span class="nombre-stat">{{ car.nombre }}</span>
            </div>
            
            <div class="stat-mid" :class="{'interactivo': !modoEdicion}" @click="!modoEdicion && tirarEstadistica(car.nombre, car.id)">
              <div class="modificador-gigante" :title="!modoEdicion ? 'Tirar Prueba de ' + car.nombre : ''">{{ calcModStr(pj[car.id]) }}</div>
              <div class="puntuacion-base">
                <input v-if="modoEdicion" type="number" v-model="pj[car.id]" class="input-stat-chico" @click.stop />
                <span v-else>{{ pj[car.id] }}</span>
              </div>
            </div>

            <div class="stat-skills">
              <div v-for="hab in car.habilidades" :key="hab.id" 
                   class="item-habilidad" :class="{'interactivo': !modoEdicion}" 
                   @click="!modoEdicion && tirarHabilidad(hab.nombre, car.id, pj[hab.id])"
                   :title="!modoEdicion ? 'Tirar ' + hab.nombre : ''">
                
                <input v-if="modoEdicion" type="checkbox" v-model="pj[hab.id]" class="check-hab" @click.stop />
                <span v-else class="punto-competencia" :class="{ activo: pj[hab.id] }">●</span>
                
                <span class="valor-hab">{{ calcHabilidadStr(car.id, pj[hab.id]) }}</span>
                <span class="nombre-hab" :class="{ 'texto-competente': pj[hab.id] && !modoEdicion }">{{ hab.nombre }}</span>
              </div>
            </div>
          </div>
        </div>

        <div class="grilla-detalles">
          
          <div class="panel-oscuro flex-col">
            <div class="header-seccion">
              <h3 class="titulo-dorado">RASGOS FÍSICOS</h3>
            </div>
            <div class="grilla-fisica mb-4">
              <div class="tag-fisico"><label>EDAD</label><input v-if="modoEdicion" v-model="pj.edad"/><span v-else>{{ pj.edad || '-' }}</span></div>
              <div class="tag-fisico"><label>ALTURA</label><input v-if="modoEdicion" v-model="pj.altura"/><span v-else>{{ pj.altura || '-' }}</span></div>
              <div class="tag-fisico"><label>PESO</label><input v-if="modoEdicion" v-model="pj.peso"/><span v-else>{{ pj.peso || '-' }}</span></div>
              <div class="tag-fisico"><label>OJOS</label><input v-if="modoEdicion" v-model="pj.ojos"/><span v-else>{{ pj.ojos || '-' }}</span></div>
              <div class="tag-fisico"><label>PIEL</label><input v-if="modoEdicion" v-model="pj.piel"/><span v-else>{{ pj.piel || '-' }}</span></div>
              <div class="tag-fisico"><label>PELO</label><input v-if="modoEdicion" v-model="pj.pelo"/><span v-else>{{ pj.pelo || '-' }}</span></div>
            </div>

            <div class="header-seccion">
              <h3 class="titulo-dorado">NOTAS Y REGISTROS</h3>
              <button v-if="modoEdicion" @click="agregarNota" class="btn-add">+ Añadir Nota</button>
            </div>
            <div class="lista-notas">
              <div v-for="(nota, idx) in pj.notas_array" :key="idx" class="bloque-nota relativo">
                <button v-if="modoEdicion" @click="borrarNota(idx)" class="btn-borrar-absoluto">Borrar</button>
                <div class="nota-header pr-borrar">
                  <input v-if="modoEdicion" v-model="nota.titulo" class="input-nota-tit" placeholder="Título de la nota"/>
                  <h4 v-else class="texto-nota-tit">{{ nota.titulo || 'Nota sin título' }}</h4>
                </div>
                <div class="nota-body">
                  <textarea v-if="modoEdicion" v-model="nota.texto" rows="4" placeholder="Escribe aquí..."></textarea>
                  <p v-else class="texto-wrap">{{ nota.texto || 'Vacío.' }}</p>
                </div>
              </div>
              <p v-if="!modoEdicion && pj.notas_array.length === 0" class="texto-vacio">No hay notas registradas.</p>
            </div>
          </div>

          <div class="panel-oscuro flex-col">
            <div class="header-seccion-busqueda">
              <h3 class="titulo-dorado">ATAQUES Y CONJUROS</h3>
              <div class="contenedor-filtro">
                <input v-model="filtroAtaques" placeholder="Buscar ataque..." class="input-buscar-interno" />
              </div>
              <button v-if="modoEdicion" @click="agregarAtaque" class="btn-add">+ Añadir</button>
            </div>

            <div class="lista-ataques">
              <div v-for="(atk, idx) in ataquesFiltrados" :key="idx" class="bloque-ataque relativo" :class="{'bloque-interactivo': !modoEdicion}">
                <button v-if="modoEdicion" @click="borrarAtaque(idx)" class="btn-borrar-absoluto">Borrar</button>

                <div class="ataque-stats pr-borrar">
                  <div class="atk-campo nom"><label>NOMBRE DEL ATAQUE</label><input v-if="modoEdicion" v-model="atk.nombre" placeholder="Ej: Espada Larga"/><span v-else class="texto-bold texto-wrap">{{ atk.nombre || '-' }}</span></div>
                  
                  <div class="atk-campo">
                    <label>BONO ATQ.</label>
                    <input v-if="modoEdicion" type="number" v-model="atk.bono" placeholder="0" class="input-min w-30" />
                    <span v-else class="badge-atq">{{ (atk.bono >= 0 ? '+' : '') }}{{ atk.bono || 0 }}</span>
                  </div>
                  
                  <div class="atk-campo">
                    <label>DAÑO</label>
                    <div v-if="modoEdicion" class="dano-inputs">
                      <input type="number" v-model="atk.cant_dados" placeholder="1" class="input-min w-30" />
                      <span class="dano-sep">d</span>
                      <select v-model="atk.tipo_dado" class="input-min select-dado">
                        <option value="4">4</option><option value="6">6</option><option value="8">8</option><option value="10">10</option><option value="12">12</option><option value="20">20</option>
                      </select>
                      <span class="dano-sep">+</span>
                      <input type="number" v-model="atk.bono_dano" placeholder="0" class="input-min w-30" />
                    </div>
                    <div v-else class="vista-dano-fijo">
                      <span class="badge-dano">{{ atk.cant_dados || 1 }}d{{ atk.tipo_dado || 8 }} {{ (atk.bono_dano >= 0 ? '+' : '') }}{{ atk.bono_dano || 0 }}</span>
                    </div>
                  </div>
                  
                  <div class="atk-campo"><label>RANGO</label><input v-if="modoEdicion" v-model="atk.rango" placeholder="Cuerpo"/><span v-else>{{ atk.rango || '-' }}</span></div>
                </div>
                
                <div class="ataque-desc">
                  <label>DESCRIPCIÓN</label>
                  <textarea v-if="modoEdicion" v-model="atk.desc" rows="2" placeholder="Efectos..."></textarea>
                  <p v-else class="texto-wrap">{{ atk.desc || 'Sin descripción.' }}</p>
                </div>

                <div v-if="!modoEdicion" class="overlay-ataque">
                  <button @click="tirarAtaqueHit(atk)" class="btn-tactico hit">🎯 Tirar Ataque <br><small>(d20 + {{atk.bono || 0}})</small></button>
                  <button @click="tirarAtaqueDano(atk)" class="btn-tactico dmg">🩸 Tirar Daño <br><small>({{atk.cant_dados || 1}}d{{atk.tipo_dado || 8}} + {{atk.bono_dano || 0}})</small></button>
                </div>
              </div>
              <p v-if="ataquesFiltrados.length === 0" class="texto-vacio">No se encontraron ataques.</p>
            </div>
          </div>

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
                  <h3 class="titulo-dorado">INVENTARIO</h3>
                  <div class="contenedor-filtro">
                    <input v-model="filtroInventario" placeholder="Buscar..." class="input-buscar-interno" />
                  </div>
                  <button v-if="modoEdicion" @click="agregarItem" class="btn-add">+ Añadir</button>
                </div>
                
                <div class="lista-inventario">
                  <div v-for="(item, idx) in inventarioFiltrado" :key="idx" class="item-inv relativo" :class="{'equipado': item.equipado}">
                    <button v-if="modoEdicion" @click="borrarItem(idx)" class="btn-borrar-absoluto">Borrar</button>

                    <div class="inv-fila-nom pr-borrar">
                      <div class="inv-box flex-grow"><label>NOMBRE</label><input v-if="modoEdicion" v-model="item.nombre" placeholder="Objeto"/><span v-else class="texto-bold texto-wrap">{{ item.nombre || '-' }}</span></div>
                      <div class="check-equipado" title="Marcar como Equipado">
                        <input type="checkbox" v-model="item.equipado" :disabled="!modoEdicion" />
                        <label>Equipado</label>
                      </div>
                    </div>
                    
                    <div class="inv-fila-stats">
                      <div class="inv-box cant"><label>CANT.</label><input v-if="modoEdicion" type="number" v-model="item.cant" placeholder="1"/><span v-else class="texto-dorado">{{ item.cant }}x</span></div>
                      <div class="inv-box peso"><label>PESO</label><input v-if="modoEdicion" v-model="item.peso" placeholder="Lbs"/><span v-else>{{ item.peso || '-' }}</span></div>
                    </div>
                    
                    <div class="inv-fila-nota">
                      <div class="inv-box w-full">
                        <label>NOTA</label>
                        <textarea v-if="modoEdicion" v-model="item.nota" rows="2" placeholder="Detalles..."></textarea>
                        <span v-else class="texto-gris texto-wrap">{{ item.nota || '-' }}</span>
                      </div>
                    </div>

                  </div>
                  <p v-if="inventarioFiltrado.length === 0" class="texto-vacio">Mochila vacía o sin coincidencias.</p>
                </div>
              </div>
            </div>
          </div>

        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Inter:wght@400;600&display=swap');

/* QUITAR FLECHAS DE INPUTS NUMÉRICOS */
input[type=number]::-webkit-inner-spin-button,
input[type=number]::-webkit-outer-spin-button {
  -webkit-appearance: none;
  margin: 0;
}
input[type=number] {
  -moz-appearance: textfield;
}

/* ESTRUCTURAS DE LA APP */
.pantalla-ficha { min-height: 100vh; background-color: #050505; color: #cbd5e1; font-family: 'Inter', sans-serif; font-size: 13px; position: relative; padding-bottom: 2rem; }
.filtro-oscuro { position: absolute; inset: 0; background: radial-gradient(circle at top, #111 0%, #000 100%); z-index: 0; }
.contenedor-principal { position: relative; z-index: 10; max-width: 1600px; width: 96%; margin: 0 auto; padding: 1rem; }

/* COMPONENTES DE BÚSQUEDA */
.header-seccion-busqueda { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; margin-bottom: 1rem; gap: 0.8rem; }
.contenedor-filtro { position: relative; display: flex; align-items: center; background: rgba(0, 0, 0, 0.6); border: 1px solid #334155; border-radius: 6px; padding: 0.4rem 0.6rem; flex-grow: 0.8; }
.input-buscar-interno { width: 100%; font-size: 0.85rem; border: none !important; background: transparent !important; color: white !important; padding: 0; outline: none; box-shadow: none; }
.input-buscar-interno::placeholder { color: #64748b; font-style: italic; }

/* PUNTO SUTIL PARA COMPETENCIAS */
.punto-competencia { font-size: 0.7rem; color: #1e293b; width: 12px; transition: color 0.2s; }
.punto-competencia.activo { color: #facc15; text-shadow: 0 0 5px rgba(251, 191, 36, 0.5); }
.texto-competente { color: white !important; font-weight: 600; }

/* DROPDOWN DE CORREOS */
.selector-email-container { min-width: 220px; }
.select-email-dark { background: #0f172a; border: 1px dashed #475569; color: #facc15; font-size: 0.85rem; padding: 0.2rem; border-radius: 4px; outline: none; width: 100%; cursor: pointer; }

/* UTILIDADES */
.mt-1 { margin-top: 0.25rem; } .ml-2 { margin-left: 0.5rem; } .mb-4 { margin-bottom: 1.5rem; } .flex-col { display: flex; flex-direction: column; } .w-full { width: 100%; } .flex-grow { flex-grow: 1; }
.w-30 { width: 30px !important; }
.texto-vacio { font-style: italic; color: #475569; text-align: center; padding: 1rem; margin: 0; }
.texto-bold { font-weight: bold; color: white; } .texto-dorado { color: #facc15; font-weight: bold; } .texto-gris { color: #94a3b8; font-style: italic; font-size: 0.8rem; }
.texto-wrap { white-space: pre-wrap; word-wrap: break-word; line-height: 1.4; }
.relativo { position: relative; }
.pr-borrar { padding-right: 65px; }

/* CONTROLES */
.controles-superiores { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1e293b; padding-bottom: 0.8rem; margin-bottom: 1.5rem; }
.acciones-derecha { display: flex; gap: 0.5rem; }
.btn-ghost { background: transparent; border: 1px solid #334155; color: #94a3b8; padding: 0.4rem 0.8rem; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-ghost:hover { background: #1e293b; color: white; }
.btn-dorado { background: #b45309; color: white; border: 1px solid #d97706; padding: 0.4rem 0.8rem; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-dorado:hover { background: #d97706; }
.btn-rojo { background: transparent; color: #ef4444; border: 1px solid #ef4444; padding: 0.4rem 0.8rem; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-rojo:hover { background: #ef4444; color: white; }
.btn-add { background: transparent; border: 1px dashed #3b82f6; color: #3b82f6; padding: 0.2rem 0.5rem; border-radius: 4px; cursor: pointer; font-size: 0.75rem; flex-shrink: 0; }
.btn-borrar-absoluto { position: absolute; top: 10px; right: 10px; background: rgba(127, 29, 29, 0.15); color: #f87171; border: 1px solid #7f1d1d; padding: 0.25rem 0.6rem; border-radius: 4px; font-size: 0.7rem; font-weight: bold; cursor: pointer; z-index: 5; }

/* IDENTIDAD Y VITALIDAD */
.panel-identidad { display: flex; gap: 1.5rem; background: #0a0a0c; border: 1px solid #1e293b; border-radius: 8px; padding: 1.5rem; margin-bottom: 1.5rem; }
.avatar-box { width: 120px; flex-shrink: 0; }
.avatar-img { width: 100%; height: 120px; object-fit: cover; border-radius: 6px; border: 1px solid #334155; }
.avatar-placeholder { width: 100%; height: 120px; background: #111; border: 1px dashed #334155; border-radius: 6px; display: flex; align-items: center; justify-content: center; font-size: 2rem; }
.input-fino { width: 100%; font-size: 0.7rem; color: #64748b; background: transparent; border: none; border-bottom: 1px dashed #334155; }
.datos-identidad { flex-grow: 1; display: flex; flex-direction: column; justify-content: center; }
.nombre-box { margin-bottom: 1rem; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; }
.texto-titulo { font-family: 'Cinzel', serif; font-size: 2.2rem; color: #facc15; margin: 0; line-height: 1; }
.input-titulo { width: 100%; font-family: 'Cinzel', serif; font-size: 2.2rem; color: #facc15; background: transparent; border: none; border-bottom: 1px dashed #334155; }
.tags-basicos { display: flex; gap: 1.5rem; flex-wrap: wrap; }
.tag label { display: block; font-size: 0.65rem; color: #64748b; font-weight: bold; letter-spacing: 1px; margin-bottom: 0.1rem; }
.tag span, .tag input { font-size: 1rem; font-weight: 600; color: #e2e8f0; background: transparent; border: none; border-bottom: 1px dashed #334155; }
.input-base { width: 80px; }

.bloque-vitalidad { display: flex; gap: 1.5rem; border-left: 1px solid #1e293b; padding-left: 1.5rem; }
.defensas { display: flex; flex-direction: column; gap: 0.8rem; }
.escudo-ca { position: relative; width: 55px; height: 60px; background: #0f172a; border: 2px solid #64748b; display: flex; flex-direction: column; align-items: center; justify-content: center; clip-path: polygon(50% 100%, 100% 80%, 100% 0, 0 0, 0 80%); font-size: 1.2rem; font-weight: bold; font-family: 'Cinzel'; }
.input-ca { width: 28px; text-align: center; border: none; border-bottom: 1px solid #475569; font-size: 1.2rem; font-family: 'Cinzel'; font-weight: bold; margin-bottom: 12px; color: white; background: transparent; }
.lbl-escudo { font-size: 0.55rem; color: #94a3b8; font-family: 'Inter'; position: absolute; bottom: 2px; }
.box-chico label { font-size: 0.6rem; color: #64748b; font-weight: bold; }
.val-chico { font-weight: bold; font-size: 1rem; }
.input-inline { width: 30px; text-align: center; background: transparent; border: none; border-bottom: 1px dashed #334155; color: white; }

.caja-hp { width: 180px; background: #111; border: 1px solid #334155; border-radius: 6px; padding: 0.8rem; text-align: center; }
.hp-header { display: flex; justify-content: space-between; font-size: 0.6rem; font-weight: bold; margin-bottom: 0.5rem; }
.lbl-dorado { color: #facc15; }
.hp-max-text { color: #94a3b8; }
.texto-hp-gigante { font-family: 'Cinzel'; font-size: 2.5rem; color: #fca5a5; font-weight: bold; line-height: 1; }
.input-hp-gigante { width: 80px; font-family: 'Cinzel'; font-size: 2.5rem; color: #fca5a5; text-align: center; background: transparent; border: none; border-bottom: 1px solid #fca5a5; }
.barra-hp-fondo { position: relative; height: 16px; background: #1e293b; border-radius: 8px; overflow: hidden; display: flex; align-items: center; justify-content: center; margin-top: 0.5rem;}
.barra-hp-relleno { position: absolute; left: 0; top: 0; height: 100%; background: linear-gradient(90deg, #991b1b, #ef4444); transition: width 0.3s; z-index: 1; }
.texto-porcentaje { position: relative; z-index: 2; font-size: 0.65rem; font-weight: bold; color: white; text-shadow: 1px 1px 2px black; }

.caja-muerte { background: #111; border: 1px solid #334155; border-radius: 6px; padding: 0.8rem; font-size: 0.7rem; }
.header-muerte { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; }
.header-muerte label { color: #facc15; font-weight: bold; font-size: 0.6rem; }
.btn-reinicio { background: transparent; border: 1px solid #64748b; color: #94a3b8; border-radius: 50%; width: 20px; height: 20px; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: 0.7rem; }
.death-row { display: flex; align-items: center; justify-content: space-between; margin-bottom: 0.3rem; }
.death-row span { width: 45px; color: #94a3b8; font-weight: bold; }

/* ESTADÍSTICAS Y HABILIDADES INTERACTIVAS */
.grilla-estadisticas { display: grid; grid-template-columns: repeat(6, 1fr); gap: 1rem; margin-bottom: 1.5rem; }
.caja-stat { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 8px; padding: 1rem; display: flex; flex-direction: column; align-items: center; }
.stat-top { margin-bottom: 0.5rem; }
.nombre-stat { font-family: 'Cinzel', serif; color: #facc15; font-weight: bold; font-size: 0.85rem; letter-spacing: 1px; }

.stat-mid { display: flex; align-items: flex-end; gap: 0.5rem; margin-bottom: 1rem; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; width: 100%; justify-content: center; transition: 0.2s; border-radius: 6px; }
.interactivo { cursor: pointer; position: relative; }
.interactivo:hover { background: rgba(59, 130, 246, 0.15); box-shadow: 0 0 10px rgba(59, 130, 246, 0.3); }

.modificador-gigante { font-family: 'Cinzel', serif; font-size: 2.2rem; font-weight: bold; color: white; line-height: 0.9; }
.puntuacion-base { background: #1e293b; color: #94a3b8; font-size: 0.8rem; font-weight: bold; padding: 0.1rem 0.4rem; border-radius: 4px; }
.input-stat-chico { width: 25px; font-size: 0.8rem; text-align: center; color: white; border: none; background: transparent; }
.stat-skills { width: 100%; display: flex; flex-direction: column; gap: 0.3rem; }
.item-habilidad { display: flex; align-items: center; gap: 0.5rem; font-size: 0.75rem; min-height: 18px; padding: 0.2rem; border-radius: 4px; transition: 0.2s; }
.check-hab { margin: 0; accent-color: #facc15; cursor: pointer; }
.valor-hab { width: 24px; text-align: right; color: #cbd5e1; font-family: monospace; font-weight: bold; }
.nombre-hab { color: #64748b; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; user-select: none; }

/* SECCIÓN INFERIOR PANELES */
.grilla-detalles { display: grid; grid-template-columns: 350px 1fr 400px; gap: 1.5rem; align-items: start; }
.panel-oscuro { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 8px; padding: 1.2rem; height: 100%; }
.header-seccion { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; margin-bottom: 1rem; }
.titulo-dorado { font-family: 'Cinzel', serif; color: #facc15; font-size: 1rem; margin: 0; }

textarea { width: 100%; border: 1px solid #1e293b; border-radius: 4px; padding: 0.5rem; resize: vertical; background: rgba(0,0,0,0.3); font-size: 0.8rem; line-height: 1.4; color: #cbd5e1; outline: none; }
textarea:focus { border-color: #3b82f6; }

/* ATAQUES INTERACTIVOS (OVERLAY MENU) */
.lista-ataques { display: flex; flex-direction: column; gap: 1rem; max-height: 700px; overflow-y: auto; padding-right: 0.5rem; }
.bloque-ataque { background: #111; border: 1px solid #334155; border-radius: 6px; padding: 1rem; transition: 0.2s; overflow: hidden; }
.bloque-interactivo:hover { border-color: #3b82f6; box-shadow: 0 0 15px rgba(59,130,246,0.2); }

.ataque-stats { display: flex; flex-wrap: wrap; gap: 1.5rem; align-items: center; margin-bottom: 0.5rem; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; }
.atk-campo { display: flex; flex-direction: column; }
.atk-campo.nom { flex-grow: 1; }
.atk-campo label { font-size: 0.6rem; color: #64748b; font-weight: bold; margin-bottom: 0.3rem; }
.atk-campo span, .atk-campo input { font-size: 0.9rem; font-weight: bold; color: white; background: transparent; border: none; border-bottom: 1px dashed #334155; }
.ataque-desc label { display: block; font-size: 0.6rem; color: #64748b; font-weight: bold; margin-bottom: 0.4rem; }

/* DADOS DE ATAQUE Y MODO JUGADOR */
.dano-inputs { display: flex; align-items: center; gap: 0.2rem; }
.input-min { text-align: center; font-size: 0.85rem; padding: 0.1rem; border: none; border-bottom: 1px dashed #475569; background: transparent; color: white; outline: none;}
.select-dado { background: #0f172a; border: 1px solid #334155; border-radius: 4px; padding: 0.1rem; }
.dano-sep { font-weight: bold; color: #64748b; font-size: 0.75rem; }
.vista-dano-fijo { display: flex; gap: 0.5rem; }
.badge-atq { background: rgba(59, 130, 246, 0.2); color: #93c5fd; padding: 0.2rem 0.5rem; border-radius: 4px; font-family: monospace; font-weight: bold; border: 1px solid #3b82f6; }
.badge-dano { background: rgba(220, 38, 38, 0.2); color: #fca5a5; padding: 0.2rem 0.5rem; border-radius: 4px; font-family: monospace; font-weight: bold; border: 1px solid #ef4444; }

/* OVERLAY PARA TIRAR (Se muestra al hacer hover en modo lectura) */
.overlay-ataque { position: absolute; inset: 0; background: rgba(15, 23, 42, 0.85); backdrop-filter: blur(2px); display: flex; align-items: center; justify-content: center; gap: 1rem; opacity: 0; transition: opacity 0.2s; z-index: 10; pointer-events: none; }
.bloque-interactivo:hover .overlay-ataque { opacity: 1; pointer-events: auto; }
.btn-tactico { border: none; padding: 0.6rem 1.2rem; border-radius: 6px; font-weight: bold; font-family: 'Cinzel', serif; cursor: pointer; transition: transform 0.1s; display: flex; flex-direction: column; align-items: center; }
.btn-tactico:active { transform: scale(0.95); }
.btn-tactico.hit { background: #1e3a8a; color: #bfdbfe; border: 1px solid #3b82f6; }
.btn-tactico.hit:hover { background: #2563eb; color: white; }
.btn-tactico.dmg { background: #7f1d1d; color: #fecaca; border: 1px solid #ef4444; }
.btn-tactico.dmg:hover { background: #dc2626; color: white; }
.btn-tactico small { font-family: 'Inter', sans-serif; font-size: 0.7rem; opacity: 0.8; margin-top: 0.2rem; }

/* INVENTARIO CON EQUIPADO */
.check-equipado { display: flex; align-items: center; gap: 0.3rem; background: rgba(0,0,0,0.3); padding: 0.2rem 0.5rem; border-radius: 4px; border: 1px solid #334155; }
.check-equipado label { font-size: 0.6rem; color: #94a3b8; font-weight: bold; margin: 0; cursor: pointer; }
.check-equipado input { cursor: pointer; accent-color: #3b82f6; }
.item-inv.equipado { border-color: #3b82f6; background: rgba(59, 130, 246, 0.05); }

/* FÍSICO Y NOTAS */
.grilla-fisica { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 0.5rem; }
.tag-fisico { background: #111; padding: 0.4rem; border: 1px solid #1e293b; border-radius: 4px; text-align: center; }
.tag-fisico label { display: block; font-size: 0.55rem; color: #64748b; font-weight: bold; margin-bottom: 0.2rem; }
.tag-fisico span, .tag-fisico input { font-size: 0.85rem; font-weight: bold; width: 100%; text-align: center; background: transparent; border: none; border-bottom: 1px dashed #334155; color: white; }

.lista-notas { display: flex; flex-direction: column; gap: 1rem; max-height: 500px; overflow-y: auto; padding-right: 0.5rem; }
.bloque-nota { background: #111; border: 1px solid #1e293b; border-radius: 6px; overflow: hidden; }
.nota-header { display: flex; justify-content: space-between; align-items: center; background: rgba(255,255,255,0.02); padding: 0.5rem 0.8rem; border-bottom: 1px solid #1e293b; }
.texto-nota-tit { margin: 0; font-size: 0.85rem; color: #facc15; font-family: 'Cinzel', serif; }
.input-nota-tit { font-size: 0.85rem; color: #facc15; font-family: 'Cinzel', serif; font-weight: bold; width: 100%; border: none; background: transparent; outline: none; }
.nota-body { padding: 0.8rem; }

/* INVENTARIO */
.seccion-monedas-vertical { display: flex; flex-direction: column; gap: 0.5rem; margin-right: 1rem; border-right: 1px solid #1e293b; padding-right: 1rem; }
.moneda { display: flex; flex-direction: column; align-items: center; justify-content: center; background: #111; border: 1px solid #334155; border-radius: 6px; width: 50px; padding: 0.5rem 0; font-weight: bold; font-size: 0.85rem; }
.moneda input { width: 35px; text-align: center; margin-top: 0.2rem; border: none; border-bottom: 1px solid #475569; background: transparent; color: white; outline: none; }
.pc label { color: #b45309; font-size: 0.7rem; } .pp label { color: #94a3b8; font-size: 0.7rem; } .po label { color: #facc15; font-size: 0.7rem; } .ppt label { color: #3b82f6; font-size: 0.7rem; }

.seccion-inventario-wrap { flex-grow: 1; }
.lista-inventario { display: flex; flex-direction: column; gap: 0.8rem; max-height: 600px; overflow-y: auto; padding-right: 1.2rem; }
.item-inv { background: #111; border: 1px solid #1e293b; border-radius: 6px; padding: 0.8rem; display: flex; flex-direction: column; gap: 0.4rem; transition: border-color 0.3s, background 0.3s; }
.inv-box { display: flex; flex-direction: column; }
.inv-box label { font-size: 0.55rem; color: #64748b; font-weight: bold; margin-bottom: 0.2rem; }
.inv-box input { font-size: 0.85rem; width: 100%; border: none; border-bottom: 1px dashed #334155; background: transparent; color: white; outline: none; }
.inv-box.cant input, .inv-box.peso input { width: 45px; text-align: center; }

.inv-fila-nom { display: flex; align-items: flex-start; justify-content: space-between; border-bottom: 1px solid #1e293b; padding-bottom: 0.4rem; gap: 0.5rem; }
.inv-fila-stats { display: flex; gap: 1rem; border-bottom: 1px solid #1e293b; padding-bottom: 0.4rem; }
.inv-fila-nota { padding-top: 0.2rem; }

/* SCROLLBARS */
::-webkit-scrollbar { width: 4px; }
::-webkit-scrollbar-thumb { background: #22252a; border-radius: 2px; }
::-webkit-scrollbar-thumb:hover { background: #3b82f6; }
</style>