module ShmupLib
  class CollisionManager
    ###
    # CollisionManager - Manages collisions between the player, enemies, bullets, and upgrades.
    ###

    # @return [self]
    def initialize
      # @type [Hash<Array>]
      @groups = {}
      self
    end

    # @param [Symbol] handle - The handle to use for the group
    # @return [nil]
    def add_group(handle)
      raise "Collision group [#{handle}] already added!" if @groups.has_key?(handle) # DEVELOPMENT GUARD: Feel free to remove before shipping your game.
      @groups[handle] = []
      nil
    end

    # @param [Symbol] handle - The handle of the group
    # @return [Array] A reference to the collision group. Be careful.
    def get_group(handle)
      @groups[handle]
    end

    # @param [Symbol] handle - The handle of the group
    # @param [Array<Object>] objects - The objects to add
    # @return [nil]
    def add_to_group(handle, *objects)
      raise "Collision group [#{handle}] is undefined!" unless @groups.has_key?(handle) # DEVELOPMENT GUARD: Feel free to remove before shipping your game.
      raise "Added object does not have a collider that is a GeoGeo shape!" unless objects[0].collider.respond_to?(:__internal_test_mtx_idx, true)
      @groups[handle].concat(objects)
      nil
    end

    # @param [Symbol] handle - The handle of the group
    # @param [Object] object - The object to add to the group
    # @return [Boolean]
    def del_from_group(handle, object)
      raise "Collision group [#{handle}] is undefined!" unless @groups.has_key?(handle) # DEVELOPMENT GUARD: Feel free to remove before shipping your game.
      !!@groups[handle].delete(object)
    end

    # @param [Symbol] handle The handle for the first collision group.
    # @return [Hash<Array>] A hash with objects as keys, and an array of colliding objects as the values. If an object doesn't collide, it won't be a key.
    def find_all_collisions_within(handle)
      __collide_within(handle, :none)
    end

    # @param [Symbol] handle1 The handle for the first collision group.
    # @param [Symbol] handle2 The handle for the second collision group.
    # @return [Hash<Array>] A hash with objects in the first group as the keys, and an array of colliding objects in the second group as the values.
    def find_all_collisions_between(handle1, handle2)
      return find_all_collisions_within(handle1) if handle1 == handle2
      __collide_between(handle1, handle2, :none)
    end

    # @param [Symbol] handle1 The handle for the first collision group.
    # @param [Symbol] handle2 The handle for the second collision group.
    # @return [Boolean]
    def any_collision_between?(handle1, handle2)
      !__collide_between(handle1, handle2, :hard).empty?
    end

    # @param [Symbol] handle1 The handle for the first collision group.
    # @param [Symbol] handle2 The handle for the second collision group.
    # @return [Hash<Array>] A hash with objects as the keys, and an array of colliding objects in the second group as the values.
    def first_collision_between(handle1, handle2)
      return first_collision_within(handle1) if handle1 == handle2
      __collide_between(handle1, handle2, :hard)
    end

    # @param [Symbol] handle1 The handle for the first collision group.
    # @param [Symbol] handle2 The handle for the second collision group.
    # @return [Hash<Array>] A hash with objects as the keys, and an array of colliding objects in the second group as the values.
    def first_collisions_between(handle1, handle2)
      return first_collision_within(handle1) if handle1 == handle2
      __collide_between(handle1, handle2, :soft)
    end

    # @param [Symbol] handle The handle for the collision group.
    # @return [Boolean]
    def any_collision_within?(handle)
      !__collide_within(handle, :hard).empty?
    end

    # @param [Symbol] handle The handle for the collision group.
    # @return [Hash<Array>] A hash with objects as the keys, and an array of colliding objects in the second group as the values.
    def first_collision_within(handle)
      __collide_within(handle, :hard)
    end

    # @param [Symbol] handle The handle for the collision group.
    # @return [Hash<Array>] A hash with objects as the keys, and an array of colliding objects in the second group as the values.
    def first_collisions_within(handle)
      __collide_within(handle, :soft)
    end

    private

    # @param [Array] group
    # @return [GeoGeo::Box]
    def __group_bbox(group, start_i = nil, final_i = nil)
      i = (start_i || 0) + 1
      il = final_i || group.length
      ic = group[i-1].collider
      t = ic.top
      b = ic.bottom
      l = ic.left
      r = ic.right
      while i < il
        ic = group[i].collider
        t = ic.top if t < ic.top
        b = ic.bottom if b > ic.bottom
        r = ic.right if r < ic.right
        l = ic.left if l > ic.left
        i += 1
      end
      out = GeoGeo::Box.new(l, r, b, t)
      $args.outputs.borders << {
          x: out.x,
          y: out.y,
          w: out.w,
          h: out.h,
          r: 0,
          g: 255,
          b: 0,
          a: 128
      }.border if false
      out
    end

    # This optimization is primarily useful when members of group2 are loosely spatially ordered
    # @param [Array] group1
    # @param [Array] group2
    # @param [Integer] fj Used during recursive step. (Note: recursive step currently disabled)
    # @param [Integer] lj Used during recursive step. (Note: recursive step currently disabled)
    # @return [Array]
    def __pre_sweep_between_groups(group1, group2, fj = nil, lj = nil)
      jl = group2.length
      fj ||= 0
      lj ||= jl
      group1_bbox = __group_bbox(group1)
      group2_bbox = __group_bbox(group2, fj, lj)
      j = fj
      f_j = fj || false
      l_j = lj || jl
      flag = true
      while j < lj
        if GeoGeo::intersect?(group2[j].collider, group1_bbox)
          f_j = j if flag
          l_j = j + 1
          flag = false
        end
        j += 1
      end
      if flag
        f_j = jl
      elsif f_j != fj || l_j != lj
        group2_bbox = __group_bbox(group2, f_j, l_j)
      end
      return f_j, l_j, group1_bbox, group2_bbox
    end

    # @param [Symbol] handle1 The handle for the first collision group.
    # @param [Symbol] handle2 The handle for the second collision group.
    # @param [Symbol] bailout :none => No bailout. :soft => Finds first collision for each member of group one. :hard => Finds first collision for any member of group one.
    # @return [Hash<Array>] A hash with objects in the first group as the keys, and an array of colliding objects in the second group as the values.
    def __collide_between(handle1, handle2, bailout)
      group1 = @groups[handle1]
      group2 = @groups[handle2]
      raise "Collision group [#{handle1}] is undefined!" unless group1 # DEVELOPMENT GUARD: Feel free to remove before shipping your game.
      raise "Collision group [#{handle2}] is undefined!" unless group2 # DEVELOPMENT GUARD: Feel free to remove before shipping your game.
      colliders = {}

      return colliders if group1.length == 0 || group2.length == 0

      first_j, last_j, group1_bbox, group2_bbox = __pre_sweep_between_groups(group1, group2)
      il = group1.length

      return colliders if first_j == last_j || !GeoGeo::intersect?(group1_bbox, group2_bbox)
      # TODO: Currently using a naive, brute force check here.
      #   Maybe replace with sort and sweep? Maybe cache collision pairs?
      i = 0
      while i < il
        a = group1[i]
        if GeoGeo::intersect?(a.collider, group2_bbox)
          j = first_j
          while j < last_j
            if GeoGeo::intersect?(a.collider, group2[j].collider)
              colliders[a] = [] unless colliders.has_key? a
              colliders[a] << group2[j]
              return colliders if bailout == :hard
              break if bailout == :soft
            end
            j += 1
          end
        end
        i += 1
      end
      colliders
    end

    # @param [Symbol] handle The handle for the first collision group.
    # @param [Symbol] bailout :none => No bailout. :soft => Finds first collision for each group member. :hard => Finds first collision for any group member.
    # @return [Hash<Array>] A hash with objects as the keys, and an array of colliding objects in the second group as the values.
    def __collide_within(handle, bailout)
      group = @groups[handle]
      raise "Collision group [#{handle}] is undefined!" unless group # DEVELOPMENT GUARD: Feel free to remove before shipping your game.
      colliders = {}

      return colliders if group.length == 0

      # TODO: Currently using a naive, brute force check here.
      #   Maybe replace with sort and sweep? Maybe cache collision pairs?
      i = 0
      l = group.length
      while i < l
        a = group[i]
        next if bailout == :soft && colliders[a] != nil
        j = i + 1
        while j < l
          if GeoGeo::intersect?(a.collider, group[j].collider)
            colliders[a] = [] unless colliders.has_key? a
            colliders[a] << group[j]
            if bailout == :hard
              colliders[group[j]] = [a]
              return colliders
            elsif bailout == :soft
              colliders[group[j]] = [a]
              break
            end
          end
          j += 1
        end
        i += 1
      end
      colliders
    end
  end
end