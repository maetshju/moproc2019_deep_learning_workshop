using Flux: onehotbatch, crossentropy
using Flux.Tracker: data
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

function calculateCrossEntropy(wordName, model)
  BSON.@load "$(joinpath(datadir, wordName)).bson" mfccs labs
  mfccs = [mfccs[i,:] for i=1:size(mfccs, 1)]
  
  labs = [phn2num[lab] for lab in vec(labs)]
  labs = onehotbatch(labs, collect(1:61))
    
  labs = [labs[:,i] for i=1:size(labs, 2)]
  Flux.reset!(model)
  return Float64.(data.(crossentropy.(model.(mfccs), labs)))
end

function findBoundaries(wordName)
  BSON.@load "$(joinpath(datadir, wordName)).bson" labs
  
  boundaries = [0]
  curr = labs[1]
  
  for (i, l) in enumerate(labs)
    if l != curr
      push!(boundaries, i)
      curr = l
    end
  end
  
  return boundaries
end

function transcribe(wordName)
  BSON.@load "$(joinpath(datadir, wordName)).bson" labs
  phonemes = [labs[1]]
  for lab in labs[2:end]
    if lab != phonemes[length(phonemes)]
      push!(phonemes, lab)
    end
  end
  
  return phonemes
end

function makeTicks(boundaries, labels)
  ticks = []
  for (b, l) in zip(boundaries, labels)
    if l == "sil"
      l = "#"
    elseif l == "ao"
      l = "aa"
    end
    push!(ticks, uppercase("$(b)\n$(l)"))
  end
  
  return (boundaries, ticks)
end

function entropy(wordName, model)
  BSON.@load "$(joinpath(datadir, wordName)).bson" mfccs labs
  mfccs = [mfccs[i,:] for i=1:size(mfccs, 1)]
  
  yhat = data.(model.(mfccs))
  Flux.reset!(model)
  return Float64.([-1 * sum(y .* log.(y)) for y in yhat])
end

function entropyPlot(wordName, model; legendLocation=:bottomright)
  ent = entropy(wordName, model)
  t = Float64.(collect(1:length(ent)))
  b = findBoundaries(wordName)
  
  ent = predict(loess(t, ent), t)
  
  p = plot(t, ent, lab="Entropy", title=wordName, ylab="Entropy", xlab="Frame number", legend=legendLocation)
  ticks = makeTicks(b, transcribe(wordName))
  p = vline!(b, lab="Boundaries", xticks=ticks)
  
  return p
end
