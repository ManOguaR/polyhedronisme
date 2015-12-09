# Polyhédronisme
#===================================================================================================
#
# A toy for constructing and manipulating polyhedra and other meshes
#
# Includes implementation of the conway polyhedral operators derived
# from code by mathematician and mathematical sculptor
# George W. Hart http://www.georgehart.com/
#
# Copyright 2011, Anselm Levskaya
# Released under the MIT License


#===================================================================================================
# Canonicalization Algorithms
#===================================================================================================

# Slow Canonicalization Algorithm
# ----------------------------------------------------------------
#
# This algorithm has some convergence problems, what really needs to be done is to
# sum the three forcing factors together as a conherent force and to use a half-decent
# integrator to make sure that it converges well as opposed to the current hack of
# ad-hoc stability multipliers.  Ideally one would implement a conjugate gradient
# descent or similar pretty thing.
#
# Only try to use this on convex polyhedra that have a chance of being canonicalized,
# otherwise it will probably blow up the geometry.  A much trickier / smarter seed-symmetry
# based geometrical regularizer should be used for fancier/weirder polyhedra.

# adjusts vertices on edges such that each edge is tangent to an origin sphere
tangentify = (xyzs, edges) ->
  STABILITY_FACTOR = 0.1 # Hack to improve convergence
  newVs = copyVecArray(xyzs) #copy vertices
  for e in edges
    t = tangentPoint( newVs[e[0]], newVs[e[1]] ) #the point closest to origin
    c = mult(STABILITY_FACTOR*1/2*(1-sqrt(dot(t,t))), t) # adjustment from sphere
    newVs[e[0]] = add(newVs[e[0]], c)
    newVs[e[1]] = add(newVs[e[1]], c)
  newVs

# recenters entire polyhedron such that center of mass is at origin
recenter = (xyzs, edges) ->
  edgecenters = (tangentPoint(xyzs[a], xyzs[b]) for [a,b] in edges) #centers of edges
  polycenter = [0,0,0]
  for v in edgecenters # sum centers to find center of gravity
    polycenter = add(polycenter, v)
  polycenter = mult(1/edges.length, polycenter)
  _.map(xyzs, (x)->sub(x, polycenter) ) # subtract off any deviation from center

# rescales maximum radius of polyhedron to 1
rescale = (xyzs) ->
  polycenter = [0,0,0]
  maxExtent = _.max(_.map(xyzs,(x)->mag(x)))
  s = 1/maxExtent
  _.map(xyzs,(x)->[s*x[0],s*x[1],s*x[2]])

# adjusts vertices in each face to improve its planarity
planarize = (xyzs, faces) ->
  STABILITY_FACTOR = 0.1 # Hack to improve convergence
  newVs = copyVecArray(xyzs) # copy vertices
  for f in faces
    coords = (xyzs[v] for v in f)
    n = normal(coords) # find avg of normals for each vertex triplet
    c = calcCentroid(coords) # find planar centroid
    if dot(n,c) < 0 # correct sign if needed
      n = mult(-1.0,n)
    for v in f  # project (vertex - centroid) onto normal, subtract off this component
      newVs[v] = add(newVs[v], mult(dot(mult(STABILITY_FACTOR, n), sub(c, xyzs[v])), n) )
  newVs

# combines above three constraint adjustments in iterative cycle
canonicalize = (poly, Niter) ->
  Niter or= 1
  console.log "Canonicalizing #{poly.name}..."
  faces = poly.face
  edges = poly.edges()
  newVs = poly.xyz
  maxChange=1.0 # convergence tracker
  for i in [0..Niter]
    oldVs = copyVecArray(newVs) #copy vertices
    newVs = tangentify(newVs, edges)
    newVs = recenter(newVs, edges)
    newVs = planarize(newVs, faces)
    maxChange=_.max(_.map(_.zip(newVs,oldVs), ([x,y])->mag(sub(x,y)) ))
    if maxChange < 1e-8
      break
  # one should now rescale, but not rescaling here makes for very interesting numerical
  # instabilities that make interesting mutants on multiple applications...
  # more experience will tell what to do
  #newVs = rescale(newVs)
  console.log "[canonicalization done, last |deltaV|="+maxChange+"]"
  #newVs
  newpoly=new polyhedron(newVs, poly.face, poly.name)
  console.log "canonicalize" , newpoly
  newpoly

# Hacky Canonicalization Algorithm
# --------------------------------------------------------------------
# Using center of gravity of vertices for each face to planarize faces

# get the spherical reciprocals of face centers
reciprocalC = (poly) ->
  centers = poly.centers()
  for c in centers
    c = mult(1.0/dot(c,c), c)
  centers

# make array of vertices reciprocal to given planes
reciprocalN = (poly) ->
  ans = []
  for f in poly.face #for each face
    centroid    = [0,0,0] # running sum of vertex coords
    normalV     = [0,0,0] # running sum of normal vectors
    avgEdgeDist =    0.0  # running sum for avg edge distance

    [v1, v2] = f[-2..-1]
    for v3 in f
      centroid     = add centroid, poly.xyz[v3]
      normalV      = add normalV, orthogonal(poly.xyz[v1], poly.xyz[v2], poly.xyz[v3])
      avgEdgeDist += edgeDist(poly.xyz[v1], poly.xyz[v2])
      [v1, v2] = [v2, v3] # shift over one

    centroid    = mult(1.0/f.length, centroid)
    normalV     = unit(normalV)
    avgEdgeDist = avgEdgeDist / f.length
    tmp         = reciprocal mult dot(centroid, normalV), normalV # based on face
    ans.push mult((1 + avgEdgeDist) / 2, tmp) # edge correction

  ans

canonicalXYZ = (poly, nIterations) ->
  nIterations or= 1
  dpoly = dual(poly)
  console.log "Pseudo-canonicalizing #{poly.name}..."

  # iteratively reciprocate face normals
  for count in [0...nIterations]
    dpoly.xyz = reciprocalN(poly)
    poly.xyz  = reciprocalN(dpoly)

  new polyhedron(poly.xyz, poly.face, poly.name)


# quick planarization
adjustXYZ = (poly, nIterations) ->
  nIterations or= 1
  dpoly = dual(poly) # v's of dual are in order of arg's f's
  console.log "Planarizing #{poly.name}..."

  for count in [0...nIterations]
    # reciprocate face centers
    dpoly.xyz = reciprocalC(poly)
    poly.xyz  = reciprocalC(dpoly)

  new polyhedron(poly.xyz, poly.face, poly.name)


