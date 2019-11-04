using Flux: onehotbatch
using ProgressBars
using Random
using BSON

const datadir = "sR_bson_subset"

const PHONES = split("h#	q	eh	dx	iy	r	ey	ix	tcl	sh	ow	z	s	hh	aw	m	t	er	l	w	aa	hv	ae	dcl	y	axr	d	kcl	k	ux	ng	gcl	g	ao	epi	ih	p	ay	v	n	f	jh	ax	en	oy	dh	pcl	ah	bcl	el	zh	uw	pau	b	uh	th	ax-h	em	ch	nx	eng")
phn2num = Dict(phone=>i for (i, phone) in enumerate(PHONES))
phn2num["sil"] = 1


function loadData()
  Xs, Ys = Vector(), Vector()
  println("Loading data")
  for fname in ProgressBar(readdir(datadir))
    BSON.@load joinpath(datadir, fname) mfccs labs
    
    mfccs = [mfccs[i,:] for i=1:size(mfccs, 1)]
    
    push!(Xs, mfccs)
    
    labs = [phn2num[lab] for lab in vec(labs)]
    labs = onehotbatch(labs, collect(1:61))
    
    labs = [labs[:,i] for i=1:size(labs, 2)]
    
    push!(Ys, labs)
  end
  
  return [x for x in Xs], [y for y in Ys]
end

function makeBatches(d, batchSize)
  batches = []
  
  for i=1:floor(Int64, length(d) / batchSize)
    startI = (i - 1) * 5 + 1
    lastI = min(startI + 4, length(d))
    
    batch = d[startI:lastI]
    
    batch = Flux.batchseq(batch, zeros(length(batch[1][1])))
    push!(batches, batch)
  end
  return batches
end

function shuffleData(Xs, Ys)
  indices = collect(1:length(Xs))
  shuffle!(indices)
  return Xs[indices], Ys[indices]
end

function prepData(Xs, Ys)
  XsShuffled, YsShuffled = shuffleData(Xs, Ys)
  XsBatched = makeBatches(XsShuffled, BATCH_SIZE)
  YsBatched = makeBatches(YsShuffled, BATCH_SIZE)
  return collect(zip(XsBatched, YsBatched))
end
