// Coordenadas de los sólidos, con la cara de lectura orientada hacia la cámara.
const tau = 2 * Math.PI
const punto = (radio, angulo, z) => [radio * Math.cos(angulo), radio * Math.sin(angulo), z]
const producto = (a, b) => a.reduce((s, v, i) => s + v * b[i], 0)
const cruz = ([x,y,z], [a,b,c]) => [y*c-z*b, z*a-x*c, x*b-y*a]
const unidad = v => v.map(n => n / Math.hypot(...v))
const centro = puntos => puntos.reduce((s, p) => s.map((n,i) => n + p[i] / puntos.length), [0,0,0])

function orientar(vertices, caras) {
  const frente = unidad(centro(caras[0].map(i => vertices[i])))
  const arriba = unidad(vertices[caras[0][0]].map((n,i) => n - producto(vertices[caras[0][0]], frente) * frente[i]))
  const derecha = cruz(arriba, frente)
  const radio = Math.max(...vertices.map(v => Math.hypot(...v)))
  return { vertices: vertices.map(v => [derecha, arriba, frente].map(eje => producto(v, eje) / radio)), caras }
}

const tetra = orientar([[1,1,1],[1,-1,-1],[-1,1,-1],[-1,-1,1]], [[0,1,2],[0,3,1],[0,2,3],[1,3,2]])
const cubo = orientar([[-1,1,1],[1,1,1],[1,-1,1],[-1,-1,1],[-1,1,-1],[1,1,-1],[1,-1,-1],[-1,-1,-1]],
  [[0,1,2,3],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0],[4,7,6,5]])
const octa = orientar([[0,0,1],[1,0,0],[0,1,0],[-1,0,0],[0,-1,0],[0,0,-1]],
  [[0,1,2],[0,2,3],[0,3,4],[0,4,1],[5,2,1],[5,3,2],[5,4,3],[5,1,4]])

function construirD10() {
  const h = Math.tan(Math.PI / 10) ** 2
  const vertices = [[0,0,1],[0,0,-1],...Array.from({length:10}, (_,i) => punto(.93, i*tau/10, i%2 ? -h : h))]
  const caras = []
  const anillo = i => 2 + i % 10
  for (let i = 0; i < 10; i++) caras.push([i%2, anillo(i), anillo(i+1), anillo(i+2)])
  return orientar(vertices, caras)
}

function construirD20() {
  const vertices = [[0,0,1],[0,0,-1]]
  const caras = []
  for (let i = 0; i < 10; i++) vertices.push(punto(2/Math.sqrt(5), i*tau/10, (i%2 ? -1 : 1)/Math.sqrt(5)))
  for (let i = 0; i < 10; i += 2) {
    const a = 2+i, b = 3+i, c = 2+(i+2)%10, d = 2+(i+3)%10
    caras.push([0,a,c],[a,b,c],[b,d,c],[1,d,b])
  }
  return orientar(vertices, caras)
}

// El dodecaedro es el dual del icosaedro. Cada vértice reúne cinco caras.
function construirD12(ico) {
  const vertices = ico.caras.map(cara => unidad(centro(cara.map(i => ico.vertices[i]))))
  const caras = ico.vertices.map((normal,i) => {
    const eje = unidad(cruz(normal, Math.abs(normal[2]) > .9 ? [0,1,0] : [0,0,1]))
    const otro = cruz(normal, eje)
    const angulo = v => Math.atan2(producto(v, otro), producto(v, eje))
    return ico.caras.flatMap((cara,j) => cara.includes(i) ? [j] : []).sort((a,b) => angulo(vertices[a]) - angulo(vertices[b]))
  })
  return orientar(vertices, caras)
}

const ico = construirD20()
const modelos = {4: tetra, 6: cubo, 8: octa, 10: construirD10(), 12: construirD12(ico), 20: ico}
export const materiales = {4: 12, 6: 37, 8: 155, 10: 193, 12: 274, 20: 238, 100: 182}

export function pintarDado(ctx, caras, valor, giro, orden, marca, percentil) {
  const {vertices, caras: facetas} = modelos[caras] || ico
  const avance = 1 - giro
  const energia = Math.pow(avance, 1.65)
  const ax = (caras <= 6 ? -.44 : -.20) + energia * (4.8 + (orden%4)*.42)
  const ay = (caras <= 6 ? .54 : .18) + energia * (orden%2 ? -8.2 : 8.2)
  const anguloReposo = caras === 6 ? -.58 : -.08
  const az = anguloReposo + energia * (orden%2 ? 2 : -2)
  const [cx,sx,cy,sy,cz,sz] = [Math.cos(ax),Math.sin(ax),Math.cos(ay),Math.sin(ay),Math.cos(az),Math.sin(az)]
  const rotados = vertices.map(([x,y,z]) => {
    const yy = y*cx-z*sx, zz = y*sx+z*cx
    const xx = x*cy+zz*sy
    return [xx*cz-yy*sz, xx*sz+yy*cz, zz*cy-x*sy]
  })
  const tono = materiales[percentil ? 100 : caras] ?? 238
  const salto = Math.abs(Math.sin(giro*Math.PI*2.5)) * energia * 11
  const proyectar = ([x,y,z]) => [50+x*(40+3*z), 54-y*(40+3*z)-salto]
  ctx.clearRect(0,0,100,100)
  const sombra = ctx.createRadialGradient(50,86,0,50,86,29)
  sombra.addColorStop(0,'rgba(0,0,0,.62)')
  sombra.addColorStop(1,'rgba(0,0,0,0)')
  ctx.save()
  ctx.translate(0,86)
  ctx.scale(1,.25)
  ctx.translate(0,-86)
  ctx.fillStyle = sombra
  ctx.fillRect(15,55,70,62)
  ctx.restore()
  const visibles = []
  facetas.forEach((indices,i) => {
    const puntos = indices.map(j => rotados[j])
    const c = centro(puntos)
    const normal = unidad(cruz(puntos[1].map((v,k) => v-puntos[0][k]), puntos[2].map((v,k) => v-puntos[0][k])))
    if (producto(normal,c)<0) normal.forEach((v,k) => { normal[k] = -v })
    if (normal[2] > -.04) visibles.push({i, c, normal, puntos: puntos.map(proyectar)})
  })
  visibles.sort((a,b) => a.c[2]-b.c[2])
  for (const {i,c,normal,puntos} of visibles) {
    const luz = Math.max(0,producto(normal,[-.45,.64,.62]))
    const l = 19 + 34*luz
    const [x,y] = proyectar(c)
    const g = ctx.createLinearGradient(x-14,y-19,x+17,y+20)
    g.addColorStop(0,`hsl(${tono-6} 52% ${l+12}%)`)
    g.addColorStop(1,`hsl(${tono+6} 56% ${l-8}%)`)
    ctx.beginPath()
    puntos.forEach(([px,py],j) => j ? ctx.lineTo(px,py) : ctx.moveTo(px,py))
    ctx.closePath()
    ctx.fillStyle = g
    ctx.fill()
    ctx.strokeStyle = `hsla(${tono-5},65%,82%,.68)`
    ctx.lineWidth = .86
    ctx.stroke()
    if (normal[2] < .35) continue
    const lateral = i !== 0
    if (lateral || valor == null) {
      ctx.strokeStyle = 'rgba(240,231,215,.3)'
      ctx.beginPath()
      puntos.forEach(([px,py],j) => {
        const xx = px*.77+x*.23, yy = py*.77+y*.23
        if (j) ctx.lineTo(xx,yy)
        else ctx.moveTo(xx,yy)
      })
      ctx.closePath()
      ctx.lineWidth = .55
      ctx.stroke()
    }
    if (lateral && (valor == null || normal[2] < .58)) continue
    let n = valor ?? '✧'
    if (lateral) {
      if (percentil) {
        const digito = ((typeof valor === 'string' ? Number(valor)/10 : valor) + i) % 10
        n = typeof valor === 'string' ? String(digito*10).padStart(2,'0') : digito
      } else n = (Number(valor)-1+i) % caras + 1
    }
    ctx.save()
    ctx.translate(x,y)
    ctx.scale(1,Math.max(.56,normal[2]))
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.font = `bold ${lateral ? 13 : caras===20 ? 22 : 24}px Georgia, serif`
    ctx.fillStyle = lateral ? '#e4dcdbbb' : marca ? '#ffe19a' : '#fff9ed'
    ctx.shadowColor = '#111020'
    ctx.shadowBlur = 2
    ctx.fillText(n,0,1)
    ctx.restore()
  }
}
