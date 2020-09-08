module Images
    using FileIO
    using ImageIO
    export clip_image
    function clip_image(filename)
        t = load(filename)
        v1 = findfirst(i->any(x->x.r != 1 || x.b != 1 || x.g != 1, t[i, :]), 1:size(t, 1))
        v2 = findlast(i->any(x->x.r != 1 || x.b != 1 || x.g != 1, t[i, :]), 1:size(t, 1))
        h1 = findfirst(i->any(x->x.r != 1 || x.b != 1 || x.g != 1, t[:, i]), 1:size(t, 2))
        h2 = findlast(i->any(x->x.r != 1 || x.b != 1 || x.g != 1, t[:, i]), 1:size(t, 2))
        save(filename, t[v1:v2, h1:h2])
    end
end
