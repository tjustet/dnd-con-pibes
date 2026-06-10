<script setup>
import { ref, computed, onMounted } from 'vue'

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()

const cargando = ref(true)
const campana = ref({ nombre: 'Cargando Mesa del DM...' })

// Listas de datos universales
const todosLosPjsDeCampana = ref([])
const personajesActivos = ref([])
const npcs = ref([])
const enemigos = ref([])

// Modales de Control
const modalDetalleAbierto = ref(false)
const entidadSeleccionada = ref(null)
const tipoEntidadSeleccionada = ref('')

const modalCrearNpcAbierto = ref(false)
const modalCrearEnemigoAbierto = ref(false)
const modalAgregarJugadorAbierto = ref(false)

const nuevoNpc = ref({
  nombre: '', armadura: 10, hp_max: 10, hp_actual: 10, velocidad: 30,
  fuerza: 10, destreza: 10, constitucion: 10, inteligencia: 10, sabiduria: 10, carisma: 10,
  vulnerabilidades: '', inmunidades: '', dificultad: 10, xp: 100, ataques: '', objetos: '', imagen_url: ''
})

const nuevoEnemigo = ref({
  nombre: '', armadura: 10, hp_max: 10, hp_actual: 10, velocidad: 30,
  fuerza: 10, destreza: 10, constitucion: 10, inteligencia: 10, sabiduria: 10, carisma: 10,
  vulnerabilidades: '', inmunidades: '', dificultad: 10, xp: 100, ataques: '', objetos: '', imagen_url: ''
})

const calcMod = (val) => Math.floor((val - 10) / 2)
const calcModStr = (val) => {
  const m = calcMod(val)
  return m >= 0 ? `+${m}` : `${m}`
}

// Layout de jugadores
const jugadoresIzquierda = computed(() => personajesActivos.value.slice(0, 3))
const jugadoresDerecha = computed(() => personajesActivos.value.slice(3, 5))
const jugadoresSuperiores = computed(() => personajesActivos.value.slice(5))

// ==========================================
// MOTOR DE LA MESA CENTRAL DEL DM
// ==========================================
const dmHistorial = ref([])
const dmPool = ref([])
const dmBono = ref(0)
const dmTirando = ref(false)
const dmDadosEnMesa = ref([])
const dmResultadoFinal = ref(0)

const agregarDadoDm = (caras) => dmPool.value.push(caras)
const limpiarPoolDm = () => { 
  dmPool.value = []
  dmBono.value = 0
  dmDadosEnMesa.value = []
  dmResultadoFinal.value = 0
}

const tirarPoolDm = () => {
  if (dmPool.value.length === 0) return
  dmTirando.value = true
  dmResultadoFinal.value = 0

  const arrayDeCaras = [...dmPool.value]
  const bonoNum = parseInt(dmBono.value) || 0

  // Animación
  const intervalo = setInterval(() => {
    dmDadosEnMesa.value = arrayDeCaras.map(c => ({ caras: c, valor: Math.floor(Math.random() * c) + 1 }))
  }, 100)

  // Fin Tirada
  setTimeout(() => {
    clearInterval(intervalo)
    let suma = 0
    dmDadosEnMesa.value = arrayDeCaras.map(c => {
      const v = Math.floor(Math.random() * c) + 1
      suma += v
      return { caras: c, valor: v }
    })
    
    dmResultadoFinal.value = suma + bonoNum
    dmTirando.value = false

    dmHistorial.value.unshift({
      id: Date.now(),
      dadosStr: dmDadosEnMesa.value.map(d => `d${d.caras}[${d.valor}]`).join(', '),
      bono: bonoNum,
      total: dmResultadoFinal.value
    })

    if (dmHistorial.value.length > 15) dmHistorial.value.pop()
  }, 1200)
}


const cargarMesaDM = async () => {
  cargando.value = true
  const { data: cData } = await supabase.from('campaigns').select('*').eq('id', route.params.id).single()
  if (cData) campana.value = cData

  const { data: pData } = await supabase.from('characters').select('*').eq('campaign_id', route.params.id)
  if (pData) {
    todosLosPjsDeCampana.value = pData
    personajesActivos.value = [...pData]
  }
  cargando.value = false
}

const agregarJugadorAlTablero = (pj) => {
  if (!personajesActivos.value.some(p => p.id === pj.id)) personajesActivos.value.push(pj)
  modalAgregarJugadorAbierto.value = false
}

const desvincularJugador = (id) => { personajesActivos.value = personajesActivos.value.filter(p => p.id !== id) }

const guardarNpc = () => {
  nuevoNpc.value.hp_actual = nuevoNpc.value.hp_max
  npcs.value.push({ ...nuevoNpc.value, id: Date.now() })
  modalCrearNpcAbierto.value = false
  nuevoNpc.value = { nombre: '', armadura: 10, hp_max: 10, hp_actual: 10, velocidad: 30, fuerza: 10, destreza: 10, constitucion: 10, inteligencia: 10, sabiduria: 10, carisma: 10, vulnerabilidades: '', inmunidades: '', dificultad: 10, xp: 100, ataques: '', objetos: '', imagen_url: '' }
}

const guardarEnemigo = () => {
  nuevoEnemigo.value.hp_actual = nuevoEnemigo.value.hp_max
  enemigos.value.push({ ...nuevoEnemigo.value, id: Date.now() })
  modalCrearEnemigoAbierto.value = false
  nuevoEnemigo.value = { nombre: '', armadura: 10, hp_max: 10, hp_actual: 10, velocidad: 30, fuerza: 10, destreza: 10, constitucion: 10, inteligencia: 10, sabiduria: 10, carisma: 10, vulnerabilidades: '', inmunidades: '', dificultad: 10, xp: 100, ataques: '', objetos: '', imagen_url: '' }
}

const abrirDetalle = (entidad, tipo) => {
  entidadSeleccionada.value = entidad
  tipoEntidadSeleccionada.value = tipo
  modalDetalleAbierto.value = true
}

onMounted(() => { cargarMesaDM() })
</script>

<template>
  <div class="mesa-dm-pantalla">
    <div class="filtro-oscuro"></div>

    <div v-if="cargando" class="cargando">Abriendo grimorio de campaña...</div>

    <div v-else class="layout-dm">
      
      <div class="panel-superior">
        <div class="header-izq">
          <button @click="router.back()" class="btn-ghost">← Salir</button>
          <h1 class="titulo-dm">Mesa del DM: <span class="campana-name">{{ campana.nombre }}</span></h1>
        </div>
        <div class="botones-dm-acciones">
          <button @click="modalAgregarJugadorAbierto = true" class="btn-accion-dm azul">+ Jugador</button>
          <button @click="modalCrearNpcAbierto = true" class="btn-accion-dm verde">+ NPC</button>
          <button @click="modalCrearEnemigoAbierto = true" class="btn-accion-dm rojo">+ Enemigo</button>
        </div>
      </div>

      <div class="tablero-grid">
        
        <div class="row-superior-pjs" v-if="jugadoresSuperiores.length > 0">
          <div v-for="pj in jugadoresSuperiores" :key="pj.id" class="mini-card-pj" @click="abrirDetalle(pj, 'pj')">
            <button class="btn-sacar-tablero" @click.stop="desvincularJugador(pj.id)">✖</button>
            <img v-if="pj.imagen_url" :src="pj.imagen_url" class="card-avatar" />
            <div v-else class="card-fallback">🛡️</div>
            <div class="card-info">
              <h3>{{ pj.nombre_pj }}</h3>
              <p>HP: {{ pj.hp_actual }}/{{ pj.hp_max }}</p>
            </div>
          </div>
        </div>

        <div class="cuerpo-tablero">
          
          <div class="columna-pjs">
            <h4 class="col-titulo">Grupo (Izq)</h4>
            <div v-for="pj in jugadoresIzquierda" :key="pj.id" class="mini-card-pj" @click="abrirDetalle(pj, 'pj')">
              <button class="btn-sacar-tablero" @click.stop="desvincularJugador(pj.id)">✖</button>
              <img v-if="pj.imagen_url" :src="pj.imagen_url" class="card-avatar" />
              <div v-else class="card-fallback">🛡️</div>
              <div class="card-info">
                <h3>{{ pj.nombre_pj }}</h3>
                <div class="hp-bar-container"><div class="hp-bar-fill" :style="{width: (pj.hp_actual/pj.hp_max)*100 + '%'}"></div></div>
                <p>HP: {{ pj.hp_actual }}/{{ pj.hp_max }}</p>
              </div>
            </div>
          </div>

          <div class="centro-dados-dm">
            <div class="mesa-central-fisica">
              
              <div class="mesa-mitad-izq">
                <h4 class="tit-seccion-mesa">Registro del DM</h4>
                <div class="historial-dm-scroll">
                  <div v-for="h in dmHistorial" :key="h.id" class="hist-item-dm">
                    <div class="h-datos">{{ h.dadosStr }}</div>
                    <div class="h-bono">Bono: {{ h.bono >= 0 ? '+' : '' }}{{ h.bono }}</div>
                    <div class="h-total">{{ h.total }}</div>
                  </div>
                  <p v-if="dmHistorial.length === 0" class="txt-vacio-mesa">Esperando tiradas...</p>
                </div>
              </div>

              <div class="mesa-mitad-der">
                
                <div class="tapete-caida">
                  <div v-for="(d, idx) in dmDadosEnMesa" :key="idx" class="dado-dm-3d" :class="{'dado-girando': dmTirando, ['dado-d'+d.caras]: true}">
                    {{ d.valor }}
                  </div>
                  <div v-if="!dmTirando && dmResultadoFinal > 0" class="resultado-gigante-dm">{{ dmResultadoFinal }}</div>
                </div>

                <div class="controles-mesa">
                  <div class="fila-botones-dados">
                    <button @click="agregarDadoDm(4)">d4</button>
                    <button @click="agregarDadoDm(6)">d6</button>
                    <button @click="agregarDadoDm(8)">d8</button>
                    <button @click="agregarDadoDm(10)">d10</button>
                    <button @click="agregarDadoDm(12)">d12</button>
                    <button @click="agregarDadoDm(20)" class="d20-btn">d20</button>
                    <button @click="agregarDadoDm(100)">d100</button>
                  </div>
                  
                  <div class="fila-acciones-mesa">
                    <div class="pool-viewer">
                      <span v-if="dmPool.length === 0" class="pool-vacio">Seleccioná dados...</span>
                      <span v-for="(p, i) in dmPool" :key="i" class="pool-badge">d{{ p }}</span>
                    </div>
                    <div class="inputs-mesa-final">
                      <input type="number" v-model="dmBono" placeholder="Bono" class="input-bono-dm" title="Modificador / Bono"/>
                      <button class="btn-clear-dm" @click="limpiarPoolDm">✖</button>
                      <button class="btn-roll-dm" @click="tirarPoolDm">ROLL</button>
                    </div>
                  </div>
                </div>

              </div>

            </div>
          </div>

          <div class="columna-pjs">
            <h4 class="col-titulo">Grupo (Der)</h4>
            <div v-for="pj in jugadoresDerecha" :key="pj.id" class="mini-card-pj" @click="abrirDetalle(pj, 'pj')">
              <button class="btn-sacar-tablero" @click.stop="desvincularJugador(pj.id)">✖</button>
              <img v-if="pj.imagen_url" :src="pj.imagen_url" class="card-avatar" />
              <div v-else class="card-fallback">🛡️</div>
              <div class="card-info">
                <h3>{{ pj.nombre_pj }}</h3>
                <div class="hp-bar-container"><div class="hp-bar-fill" :style="{width: (pj.hp_actual/pj.hp_max)*100 + '%'}"></div></div>
                <p>HP: {{ pj.hp_actual }}/{{ pj.hp_max }}</p>
              </div>
            </div>
            <p v-if="personajesActivos.length === 0" class="txt-vacio-tablero">No hay jugadores.</p>
          </div>

        </div>

        <div class="fila-inferior-dm">
          
          <div class="seccion-tablero-baja verde-borde">
            <h3 class="baja-titulo t-verde">NPCs de la Sesión</h3>
            <div class="lista-baja-cards">
              <div v-for="npc in npcs" :key="npc.id" class="mini-card-pj custom-card" @click="abrirDetalle(npc, 'npc')">
                <div class="card-fallback fallback-npc">👤</div>
                <div class="card-info">
                  <h3>{{ npc.nombre }}</h3>
                  <p>HP: {{ npc.hp_actual }}/{{ npc.hp_max }} | CA: {{ npc.armadura }}</p>
                </div>
              </div>
              <p v-if="npcs.length === 0" class="txt-vacio-sub">No hay NPCs activos.</p>
            </div>
          </div>

          <div class="seccion-tablero-baja rojo-borde">
            <h3 class="baja-titulo t-rojo">Enemigos / Monstruos</h3>
            <div class="lista-baja-cards">
              <div v-for="en in enemigos" :key="en.id" class="mini-card-pj custom-card" @click="abrirDetalle(en, 'enemigo')">
                <div class="card-fallback fallback-en">💀</div>
                <div class="card-info">
                  <h3>{{ en.nombre }}</h3>
                  <p>HP: {{ en.hp_actual }}/{{ en.hp_max }} | CA: {{ en.armadura }}</p>
                </div>
              </div>
              <p v-if="enemigos.length === 0" class="txt-vacio-sub">Zona despejada.</p>
            </div>
          </div>

        </div>

      </div>
    </div>

    <div v-if="modalDetalleAbierto" class="modal-dm-overlay" @click.self="modalDetalleAbierto = false">
      <div class="modal-dm-sheet">
        <button class="close-sheet" @click="modalDetalleAbierto = false">✖</button>
        
        <div class="sheet-header">
          <h2>{{ entidadSeleccionada?.nombre || entidadSeleccionada?.nombre_pj }}</h2>
          <span class="sheet-badge">{{ tipoEntidadSeleccionada.toUpperCase() }}</span>
        </div>

        <div class="sheet-body-grid">
          <div class="sheet-row-stats">
            <div class="s-box"><label>VIDA</label><span>{{ entidadSeleccionada?.hp_actual }} / {{ entidadSeleccionada?.hp_max }}</span></div>
            <div class="s-box"><label>ARMADURA (CA)</label><span>{{ entidadSeleccionada?.clase_armadura || entidadSeleccionada?.armadura }}</span></div>
            <div class="s-box"><label>VELOCIDAD</label><span>{{ entidadSeleccionada?.velocidad }} ft</span></div>
          </div>

          <div class="sheet-atributos">
            <div class="atr-mini"><label>STR</label><span>{{ entidadSeleccionada?.fuerza }} ({{ calcModStr(entidadSeleccionada?.fuerza) }})</span></div>
            <div class="atr-mini"><label>DEX</label><span>{{ entidadSeleccionada?.destreza }} ({{ calcModStr(entidadSeleccionada?.destreza) }})</span></div>
            <div class="atr-mini"><label>CON</label><span>{{ entidadSeleccionada?.constitucion }} ({{ calcModStr(entidadSeleccionada?.constitucion) }})</span></div>
            <div class="atr-mini"><label>INT</label><span>{{ entidadSeleccionada?.inteligencia }} ({{ calcModStr(entidadSeleccionada?.inteligencia) }})</span></div>
            <div class="atr-mini"><label>WIS</label><span>{{ entidadSeleccionada?.sabiduria }} ({{ calcModStr(entidadSeleccionada?.sabiduria) }})</span></div>
            <div class="atr-mini"><label>CHA</label><span>{{ entidadSeleccionada?.carisma }} ({{ calcModStr(entidadSeleccionada?.carisma) }})</span></div>
          </div>

          <div v-if="tipoEntidadSeleccionada !== 'pj'" class="sheet-detalles-custom">
            <p><strong>Inmunidades:</strong> {{ entidadSeleccionada?.inmunidades || 'Ninguna.' }}</p>
            <p><strong>Vulnerabilidades:</strong> {{ entidadSeleccionada?.vulnerabilidades || 'Ninguna.' }}</p>
            <p><strong>CR:</strong> {{ entidadSeleccionada?.dificultad }} | <strong>XP:</strong> {{ entidadSeleccionada?.xp }}</p>
            <div class="text-block-sheet"><h4>Acciones / Ataques:</h4><p>{{ entidadSeleccionada?.ataques || 'Sin acciones.' }}</p></div>
            <div class="text-block-sheet"><h4>Loot / Objetos:</h4><p>{{ entidadSeleccionada?.objetos || 'Ninguno.' }}</p></div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="modalAgregarJugadorAbierto" class="modal-dm-overlay" @click.self="modalAgregarJugadorAbierto = false">
      <div class="modal-dm-sheet form-small">
        <h3>Vincular Héroe al Tablero Activo</h3>
        <div class="lista-vincular">
          <div v-for="p in todosLosPjsDeCampana" :key="p.id" class="item-vincular" @click="agregarJugadorAlTablero(p)">
            <span>{{ p.nombre_pj }}</span>
            <button class="btn-add-express">Añadir</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="modalCrearNpcAbierto" class="modal-dm-overlay" @click.self="modalCrearNpcAbierto = false">
      <div class="modal-dm-sheet form-box-scroll">
        <h3>Forjar Nuevo NPC</h3>
        <div class="form-grid">
          <div class="f-group"><label>Nombre</label><input v-model="nuevoNpc.nombre"/></div>
          <div class="f-group"><label>CA</label><input type="number" v-model="nuevoNpc.armadura"/></div>
          <div class="f-group"><label>HP</label><input type="number" v-model="nuevoNpc.hp_max"/></div>
          <div class="f-group"><label>Velocidad</label><input type="number" v-model="nuevoNpc.velocidad"/></div>
          <div class="form-stats-row">
            <div><label>STR</label><input type="number" v-model="nuevoNpc.fuerza"/></div>
            <div><label>DEX</label><input type="number" v-model="nuevoNpc.destreza"/></div>
            <div><label>CON</label><input type="number" v-model="nuevoNpc.constitucion"/></div>
            <div><label>INT</label><input type="number" v-model="nuevoNpc.inteligencia"/></div>
            <div><label>WIS</label><input type="number" v-model="nuevoNpc.sabiduria"/></div>
            <div><label>CHA</label><input type="number" v-model="nuevoNpc.carisma"/></div>
          </div>
          <div class="f-group full"><label>Acciones</label><textarea v-model="nuevoNpc.ataques"></textarea></div>
        </div>
        <button @click="guardarNpc" class="btn-guardar-creacion verde">Sellar NPC</button>
      </div>
    </div>

    <div v-if="modalCrearEnemigoAbierto" class="modal-dm-overlay" @click.self="modalCrearEnemigoAbierto = false">
      <div class="modal-dm-sheet form-box-scroll">
        <h3>Forjar Enemigo</h3>
        <div class="form-grid">
          <div class="f-group"><label>Nombre</label><input v-model="nuevoEnemigo.nombre"/></div>
          <div class="f-group"><label>CA</label><input type="number" v-model="nuevoEnemigo.armadura"/></div>
          <div class="f-group"><label>HP</label><input type="number" v-model="nuevoEnemigo.hp_max"/></div>
          <div class="f-group"><label>Velocidad</label><input type="number" v-model="nuevoEnemigo.velocidad"/></div>
          <div class="form-stats-row">
            <div><label>STR</label><input type="number" v-model="nuevoEnemigo.fuerza"/></div>
            <div><label>DEX</label><input type="number" v-model="nuevoEnemigo.destreza"/></div>
            <div><label>CON</label><input type="number" v-model="nuevoEnemigo.constitucion"/></div>
            <div><label>INT</label><input type="number" v-model="nuevoEnemigo.inteligencia"/></div>
            <div><label>WIS</label><input type="number" v-model="nuevoEnemigo.sabiduria"/></div>
            <div><label>CHA</label><input type="number" v-model="nuevoEnemigo.carisma"/></div>
          </div>
          <div class="f-group full"><label>Acciones</label><textarea v-model="nuevoEnemigo.ataques"></textarea></div>
        </div>
        <button @click="guardarEnemigo" class="btn-guardar-creacion rojo">Desatar Enemigo</button>
      </div>
    </div>

  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Inter:wght@400;600;700&display=swap');

/* QUITAR FLECHAS INPUTS NUMBER */
input[type=number]::-webkit-inner-spin-button, input[type=number]::-webkit-outer-spin-button { -webkit-appearance: none; margin: 0; }

.mesa-dm-pantalla { min-height: 100vh; background-color: #050505; color: #cbd5e1; font-family: 'Inter', sans-serif; position: relative; padding: 1rem; }
.filtro-oscuro { position: absolute; inset: 0; background: radial-gradient(circle at center, #18181b 0%, #000 100%); z-index: 0; }
.layout-dm { position: relative; z-index: 10; max-width: 1650px; margin: 0 auto; display: flex; flex-direction: column; gap: 1rem; }

/* BARRA SUPERIOR */
.panel-superior { display: flex; justify-content: space-between; align-items: center; background: #0a0a0c; border: 1px solid #1e293b; padding: 1rem; border-radius: 8px; box-shadow: 0 4px 15px rgba(0,0,0,0.5); }
.titulo-dm { font-family: 'Cinzel', serif; font-size: 1.6rem; color: #facc15; margin: 0; }
.campana-name { color: white; }
.header-izq { display: flex; gap: 1rem; align-items: center; }
.btn-ghost { background: transparent; border: 1px solid #334155; color: #94a3b8; padding: 0.4rem 0.8rem; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-ghost:hover { background: #1e293b; color: white; }

.botones-dm-acciones { display: flex; gap: 0.8rem; }
.btn-accion-dm { border: none; color: white; font-family: 'Cinzel', serif; font-weight: bold; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; transition: 0.2s; }
.btn-accion-dm.azul { background: #1e3a8a; border: 1px solid #3b82f6; }
.btn-accion-dm.verde { background: #064e3b; border: 1px solid #10b981; }
.btn-accion-dm.rojo { background: #7f1d1d; border: 1px solid #ef4444; }

/* TABLERO MAESTRO */
.tablero-grid { display: flex; flex-direction: column; gap: 1.5rem; margin-top: 0.5rem; }
.row-superior-pjs { display: flex; gap: 1rem; justify-content: center; background: rgba(0,0,0,0.2); padding: 0.5rem; border-radius: 8px; border: 1px dashed #1e293b; }
.cuerpo-tablero { display: grid; grid-template-columns: 280px 1fr 280px; gap: 1.5rem; align-items: start; }
.columna-pjs { background: rgba(10,10,12,0.8); border: 1px solid #1e293b; border-radius: 8px; padding: 1rem; display: flex; flex-direction: column; gap: 1rem; min-height: 400px; }
.col-titulo { font-family: 'Cinzel', serif; color: #64748b; margin: 0; border-bottom: 1px solid #1e293b; padding-bottom: 0.3rem; text-align: center; font-size: 0.85rem; }

.mini-card-pj { background: #111; border: 1px solid #334155; border-radius: 8px; padding: 0.6rem; display: flex; align-items: center; cursor: pointer; transition: 0.2s; position: relative; }
.mini-card-pj:hover { border-color: #3b82f6; background: #141417; transform: scale(1.02); }
.card-avatar { width: 50px; height: 50px; object-fit: cover; border-radius: 6px; margin-right: 0.8rem; border: 1px solid #27272a; }
.card-fallback { width: 50px; height: 50px; background: #050505; border: 1px dashed #334155; border-radius: 6px; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; margin-right: 0.8rem; }
.card-info h3 { margin: 0; font-size: 1rem; color: white; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 140px; }
.card-info p { margin: 0; font-size: 0.75rem; color: #94a3b8; margin-top: 0.2rem; }
.btn-sacar-tablero { position: absolute; top: -5px; right: -5px; background: #7f1d1d; color: white; border: none; border-radius: 50%; width: 18px; height: 18px; font-size: 0.6rem; cursor: pointer; display: flex; align-items: center; justify-content: center; opacity: 0; }
.mini-card-pj:hover .btn-sacar-tablero { opacity: 1; }
.hp-bar-container { background: #1e293b; height: 5px; border-radius: 3px; width: 100%; margin-top: 0.3rem; overflow: hidden; }
.hp-bar-fill { height: 100%; background: linear-gradient(90deg, #b91c1c, #ef4444); }

/* ========================================== */
/* LA MESA CENTRAL DE DADOS INCORPORADA       */
/* ========================================== */
.centro-dados-dm { display: flex; justify-content: center; align-items: stretch; min-height: 400px; }
.mesa-central-fisica { display: flex; width: 100%; background: #0a0a0c; border: 2px solid #3b82f6; border-radius: 12px; box-shadow: inset 0 0 30px rgba(0,0,0,0.8), 0 10px 20px rgba(0,0,0,0.5); overflow: hidden; }

/* Mitad Izquierda: Historial */
.mesa-mitad-izq { width: 250px; background: #111; border-right: 2px solid #1e293b; display: flex; flex-direction: column; padding: 1rem; }
.tit-seccion-mesa { font-family: 'Cinzel', serif; color: #facc15; margin: 0 0 1rem 0; border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; text-align: center; }
.historial-dm-scroll { flex-grow: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 0.8rem; padding-right: 0.5rem; }
.hist-item-dm { background: rgba(30, 41, 59, 0.4); border-left: 3px solid #3b82f6; padding: 0.5rem; border-radius: 4px; display: flex; flex-direction: column; }
.h-datos { font-family: monospace; color: #cbd5e1; font-size: 0.8rem; }
.h-bono { color: #93c5fd; font-size: 0.7rem; margin-top: 0.2rem; }
.h-total { color: #facc15; font-family: 'Cinzel', serif; font-size: 1.5rem; font-weight: bold; text-align: right; line-height: 1; }
.txt-vacio-mesa { font-style: italic; color: #475569; font-size: 0.8rem; text-align: center; }

/* Mitad Derecha: Tapete y Controles */
.mesa-mitad-der { flex-grow: 1; display: flex; flex-direction: column; position: relative; background: radial-gradient(circle at center, #1e293b, #050505); }

.tapete-caida { flex-grow: 1; display: flex; flex-wrap: wrap; align-items: center; justify-content: center; gap: 1.5rem; padding: 2rem; position: relative; }
.dado-dm-3d { width: 80px; height: 80px; background: linear-gradient(135deg, #2563eb, #1e3a8a); color: white; display: flex; align-items: center; justify-content: center; font-family: 'Inter', sans-serif; font-size: 2rem; font-weight: bold; box-shadow: inset 0 0 10px rgba(0,0,0,0.8), 0 5px 15px rgba(0,0,0,0.6); text-shadow: 2px 2px 4px rgba(0,0,0,0.8); }

/* Formas visuales CSS para los dados */
.dado-d20, .dado-d12, .dado-d100, .dado-d10, .dado-d8 { clip-path: polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%); }
.dado-d6 { border-radius: 8px; }
.dado-d4 { clip-path: polygon(50% 0%, 0% 100%, 100% 100%); align-items: flex-end; padding-bottom: 10px; font-size: 1.5rem; }

.dado-girando { animation: shake-roll 0.4s infinite linear, color-pulse 0.4s infinite alternate; }
@keyframes shake-roll { 0% { transform: rotate(0deg) scale(1) translateY(0); } 25% { transform: rotate(25deg) scale(1.1) translateY(-10px); } 50% { transform: rotate(0deg) scale(1) translateY(0); } 75% { transform: rotate(-25deg) scale(1.1) translateY(10px); } 100% { transform: rotate(0deg) scale(1) translateY(0); } }
@keyframes color-pulse { from { filter: brightness(1); } to { filter: brightness(1.5) drop-shadow(0 0 15px #3b82f6); } }

.resultado-gigante-dm { position: absolute; bottom: 20px; font-family: 'Cinzel', serif; font-size: 4rem; color: #facc15; font-weight: bold; text-shadow: 0 0 20px rgba(250,204,21,0.5); background: rgba(0,0,0,0.6); padding: 0 1.5rem; border-radius: 12px; border: 1px solid #334155; }

/* Botonera de abajo */
.controles-mesa { background: #0f172a; border-top: 1px solid #1e293b; padding: 1rem; display: flex; flex-direction: column; gap: 0.8rem; }
.fila-botones-dados { display: flex; justify-content: center; gap: 0.5rem; }
.fila-botones-dados button { background: #1e293b; border: 1px solid #334155; color: white; font-family: 'Cinzel', serif; font-weight: bold; padding: 0.5rem; width: 45px; border-radius: 6px; cursor: pointer; transition: 0.2s; }
.fila-botones-dados button:hover { background: #3b82f6; border-color: #60a5fa; transform: translateY(-3px); }
.d20-btn { background: #1e3a8a !important; color: #facc15 !important; border-color: #3b82f6 !important; }

.fila-acciones-mesa { display: flex; justify-content: space-between; align-items: center; background: #050505; border: 1px dashed #334155; border-radius: 6px; padding: 0.5rem; min-height: 45px; }
.pool-viewer { display: flex; gap: 0.4rem; flex-wrap: wrap; flex-grow: 1; padding-right: 1rem; }
.pool-badge { background: #1e3a8a; border: 1px solid #3b82f6; color: white; padding: 0.2rem 0.5rem; border-radius: 4px; font-family: monospace; font-size: 0.8rem; font-weight: bold; }
.pool-vacio { color: #64748b; font-style: italic; font-size: 0.85rem; }

.inputs-mesa-final { display: flex; gap: 0.5rem; align-items: center; }
.input-bono-dm { width: 60px; text-align: center; background: #111; border: 1px solid #475569; color: white; padding: 0.4rem; border-radius: 4px; font-weight: bold; }
.btn-clear-dm { background: transparent; border: 1px solid #ef4444; color: #fca5a5; padding: 0.4rem; border-radius: 4px; cursor: pointer; }
.btn-clear-dm:hover { background: #ef4444; color: white; }
.btn-roll-dm { background: #b45309; border: 1px solid #d97706; color: white; font-family: 'Cinzel', serif; font-weight: bold; font-size: 1.1rem; padding: 0.4rem 1.5rem; border-radius: 4px; cursor: pointer; }
.btn-roll-dm:hover { background: #d97706; transform: scale(1.05); }


/* FILA INFERIOR */
.fila-inferior-dm { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; }
.seccion-tablero-baja { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 8px; padding: 1.2rem; min-height: 250px; }
.seccion-tablero-baja.verde-borde { border-top: 4px solid #10b981; }
.seccion-tablero-baja.rojo-borde { border-top: 4px solid #ef4444; }
.baja-titulo { font-family: 'Cinzel', serif; margin: 0 0 1rem 0; font-size: 1.2rem; }
.t-verde { color: #10b981; } .t-rojo { color: #ef4444; }
.lista-baja-cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 0.8rem; }

/* MODALES */
.modal-dm-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.8); backdrop-filter: blur(5px); display: flex; align-items: center; justify-content: center; z-index: 99999; padding: 1rem; }
.modal-dm-sheet { background: #0a0a0c; border: 2px solid #334155; border-radius: 12px; width: 700px; max-width: 100%; padding: 2rem; position: relative; max-height: 90vh; overflow-y: auto; }
.close-sheet { position: absolute; top: 15px; right: 15px; background: transparent; border: none; color: #64748b; font-size: 1.2rem; cursor: pointer; }

.sheet-header { border-bottom: 1px solid #1e293b; padding-bottom: 0.5rem; margin-bottom: 1.5rem; display: flex; justify-content: space-between; align-items: center; }
.sheet-header h2 { font-family: 'Cinzel', serif; color: #facc15; margin: 0; }
.sheet-badge { background: #1e293b; color: #94a3b8; font-size: 0.7rem; font-weight: bold; padding: 0.2rem 0.6rem; border-radius: 4px; }
.sheet-row-stats { display: flex; gap: 1rem; margin-bottom: 1.5rem; }
.s-box { background: #111; border: 1px solid #1e293b; border-radius: 6px; padding: 0.6rem 1rem; text-align: center; flex: 1; }
.s-box label { display: block; font-size: 0.6rem; color: #64748b; font-weight: bold; }
.s-box span { font-size: 1.2rem; font-weight: bold; color: white; }
.sheet-atributos { display: grid; grid-template-columns: repeat(6, 1fr); gap: 0.5rem; margin-bottom: 1.5rem; border-bottom: 1px solid #1e293b; padding-bottom: 1.5rem; }
.atr-mini { background: #141417; border-radius: 6px; text-align: center; padding: 0.4rem; border: 1px solid #27272a; }
.atr-mini label { display: block; font-size: 0.55rem; color: #facc15; font-weight: bold; }
.atr-mini span { font-size: 0.85rem; font-weight: bold; color: white; font-family: monospace; }
.text-block-sheet { background: #111; padding: 0.8rem; border-radius: 6px; border: 1px solid #1e293b; margin-top: 1rem; }
.text-block-sheet h4 { margin: 0 0 0.4rem 0; font-family: 'Cinzel', serif; color: #cbd5e1; font-size: 0.85rem; }
.text-block-sheet p { margin: 0; font-size: 0.85rem; color: #94a3b8; white-space: pre-wrap; }

.form-box-scroll { width: 600px; }
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-top: 1rem; }
.f-group { display: flex; flex-direction: column; gap: 0.3rem; }
.f-group.full { grid-column: span 2; }
.f-group label { font-size: 0.75rem; color: #94a3b8; font-weight: bold; }
.f-group input, .f-group textarea { background: #111; border: 1px solid #334155; border-radius: 6px; padding: 0.5rem; color: white; outline: none; font-size: 0.85rem; }
.form-stats-row { grid-column: span 2; display: grid; grid-template-columns: repeat(6, 1fr); gap: 0.4rem; background: rgba(0,0,0,0.3); padding: 0.6rem; border-radius: 6px; border: 1px dashed #334155; }
.form-stats-row div { text-align: center; }
.form-stats-row input { width: 100%; text-align: center; background: #050505; border: 1px solid #27272a; color: white; border-radius: 4px; padding: 0.2rem; }
.btn-guardar-creacion { width: 100%; border: none; color: white; font-family: 'Cinzel', serif; font-weight: bold; padding: 0.8rem; border-radius: 6px; margin-top: 1.5rem; cursor: pointer; font-size: 1rem; }
.btn-guardar-creacion.verde { background: #059669; } .btn-guardar-creacion.rojo { background: #dc2626; }
.lista-vincular { display: flex; flex-direction: column; gap: 0.5rem; margin-top: 1rem; max-height: 300px; overflow-y: auto; }
.item-vincular { background: #111; border: 1px solid #1e293b; border-radius: 6px; padding: 0.6rem 1rem; display: flex; justify-content: space-between; align-items: center; cursor: pointer; }
.btn-add-express { background: transparent; border: 1px solid #3b82f6; color: #93c5fd; padding: 0.2rem 0.5rem; border-radius: 4px; font-size: 0.75rem; cursor: pointer; }

::-webkit-scrollbar { width: 4px; }
::-webkit-scrollbar-thumb { background: #22252a; border-radius: 2px; }
</style>