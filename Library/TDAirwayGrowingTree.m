classdef TDAirwayGrowingTree < TDTree
    % TDAirwayGrowingTree. A tree structure for storing an airway tree model
    % generated by a TDAirwayGrowing
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %    

    properties
        StartCoords  % [i,j,k] First point
        EndCoords    % [i,j,k] Last point
        CentrelineTreeSegment
        GenerationNumber % 1 = trachea
        IsGenerated  % True if this branch was created by the volume-filling algorithm
        Density
        
        TemporaryIndex
    end
    
    properties (Access = private)
        StrahlerOrder
        StrahlerProcessed = false        
    end
    
    methods
        function obj = TDAirwayGrowingTree(parent)
            if nargin > 0
                obj.Parent = parent;
                parent.AddChild(obj);
                obj.GenerationNumber = parent.GenerationNumber + 1;
            else
                obj.GenerationNumber = 1;
            end
        end
        
        % Returns all the branches as a set, from this branch onwards
        function branches_list = GetTerminalBranchesAsList(obj)
            branches_list = TDAirwayGrowingTree.empty();

            branches_to_do = obj;
            while ~isempty(branches_to_do)
                branch = branches_to_do(end);
                branches_to_do(end) = [];
                branch.StrahlerProcessed = false;
                branch.StrahlerOrder = [];
                if isempty(branch.Children)
                    branches_list(end+1) = branch;
                else
                    branches_to_do = [branches_to_do, branch.Children];
                end
            end
        end
        
        function AddDensityValues(obj, density_image)
            global_coordinates = density_image.CoordinatesMmToGlobalCoordinates(obj.EndCoords);
            obj.Density = density_image.GetVoxel(global_coordinates);
            for child = obj.Children
                child.AddDensityValues(density_image);
            end
        end
        
        function ComputeStrahlerOrders(obj)
            next_branches = obj.GetTerminalBranchesAsList;
            
            % Set oder of terminal branches to 1
            for branch = next_branches
                branch.StrahlerOrder = 1;
            end
            
            while ~isempty(next_branches)
                branches_to_do = next_branches;
                next_branches = TDAirwayGrowingTree.empty(1,0);
                for branch = branches_to_do
                    if ~branch.StrahlerProcessed
                        
                        % Only process this branch if all its children have been
                        % processed
                        children_processed = true;
                        for child = branch.Children
                            if ~child.StrahlerProcessed
                                children_processed = false;
                            end
                        end
                        if ~children_processed
                            next_branches(end + 1) = branch;
                        else
                            branch.StrahlerProcessed = true;
                            parent = branch.Parent;
                            if ~isempty(parent)
                                if isempty(parent.StrahlerOrder)
                                    parent.StrahlerOrder = branch.StrahlerOrder;
                                elseif parent.StrahlerOrder == branch.StrahlerOrder
                                    parent.StrahlerOrder = branch.StrahlerOrder + 1;
                                else
                                    parent.StrahlerOrder = max(branch.StrahlerOrder, parent.StrahlerOrder);
                                end
                                next_branches(end + 1) = parent;
                            end
                        end
                    end
                end
            end            
        end
        
        function start_point = StartPoint(obj)
            start_point = TDCentrelinePoint(obj.StartCoords(1), obj.StartCoords(2), obj.StartCoords(3), obj.Radius, []); 
        end
        
        function start_point = EndPoint(obj)
            start_point = TDCentrelinePoint(obj.EndCoords(1), obj.EndCoords(2), obj.EndCoords(3), obj.Radius, []);            
        end
        
        function radius = Radius(obj)
            if ~isempty(obj.CentrelineTreeSegment)
                radius = obj.CentrelineTreeSegment.Centreline(1).Radius;
            else
                if ~isempty(obj.StrahlerOrder)
                    % Compute radius based on Strahler order
                    root = obj.GetRoot;
                    max_order = root.StrahlerOrder;
                    current_order = obj.StrahlerOrder;
                    diameter_ratio = 0.7;
                    max_diameter = 2*root.Radius;
                    radius = 0.5*max_diameter*diameter_ratio^(max_order - current_order);
                else
                    throw(MException('TDAirwayGrowingTree:Radius', 'Cannot compute the radius value because the Strahler order has not been computed'));
                end
            end
        end
        
        function segment_direction = Direction(obj)
            segment_direction = obj.EndCoords - obj.StartCoords;
            segment_direction = segment_direction/norm(segment_direction);
        end
            
        function segment_length = Length(obj)
            segment_length = norm(obj.EndCoords - obj.StartCoords);
        end
        
        % Once an initial tree has been generated using AddTree(), this method
        % finds the TDAirwayGrowingTree branch which matches the
        % branch given as centreline_branch.
        function branch = FindCentrelineBranch(obj, centreline_branch, reporting)
            segments_to_do = obj;
            while ~isempty(segments_to_do)
                segment = segments_to_do(end);
                if (segment.CentrelineTreeSegment == centreline_branch)
                    branch = segment;
                    return;
                end
                segments_to_do(end) = [];
                children = segment.Children;
                segments_to_do = [segments_to_do, children];
            end
            reporting.Error('FindBranch', 'Centreline branch not found');
        end
        
    end
    
end

